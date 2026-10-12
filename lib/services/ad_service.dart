import 'dart:io';
import 'package:agl_ads/agl_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ad Unit IDs
// Real units are never committed. CI passes them at build time from
// agl-manifest/docs/admob-ids.json (scripts/agl_paths.py admob_defines) as
//   --dart-define=ADMOB_<BANNER|INTERSTITIAL|REWARDED>_<ANDROID|IOS>=<unit>
// ─────────────────────────────────────────────────────────────────────────────
class AdUnitIds {
  // ── Build-time units (empty when the define is not passed) ──────────────
  static const String _androidBanner =
      String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const String _androidInterstitial =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const String _androidRewarded =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const String _iosBanner = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const String _iosInterstitial =
      String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const String _iosRewarded =
      String.fromEnvironment('ADMOB_REWARDED_IOS');

  // ── Google's published test units, debug/profile only ───────────────────
  // https://developers.google.com/admob/android/test-ads
  // https://developers.google.com/admob/ios/test-ads
  static const String testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testAndroidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testIosRewarded =
      'ca-app-pub-3940256099942544/1712485313';

  /// `--dart-define=SCREENSHOT=true` marks a store-screenshot build. No ad may
  /// load in one: a "Test Ad" banner must never reach a store listing.
  static const bool isScreenshotBuild = bool.fromEnvironment('SCREENSHOT');

  static bool get _isIos {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// The unit to request, or null for "request no ad".
  ///
  /// A unit passed at build time is used as is. Without one, debug and profile
  /// builds fall back to Google's test unit so the integration stays testable,
  /// and a RELEASE build requests nothing: Google's test ads must never be
  /// served from a store build. A screenshot build never requests an ad.
  @visibleForTesting
  static String? resolve({
    required String define,
    required String testUnit,
    bool release = kReleaseMode,
    bool screenshot = isScreenshotBuild,
  }) {
    if (screenshot) return null;
    if (define.isNotEmpty) return define;
    return release ? null : testUnit;
  }

  // ── Getters (null = no ad for this format in this build) ────────────────
  static String? get banner => _isIos
      ? resolve(define: _iosBanner, testUnit: testIosBanner)
      : resolve(define: _androidBanner, testUnit: testAndroidBanner);
  static String? get interstitial => _isIos
      ? resolve(define: _iosInterstitial, testUnit: testIosInterstitial)
      : resolve(
          define: _androidInterstitial, testUnit: testAndroidInterstitial);
  static String? get rewarded => _isIos
      ? resolve(define: _iosRewarded, testUnit: testIosRewarded)
      : resolve(define: _androidRewarded, testUnit: testAndroidRewarded);

  /// Whether this build may touch the ad SDK at all. A screenshot build may
  /// not — it skips UMP and MobileAds initialisation entirely, so neither a
  /// consent form nor an ad can appear in a store screenshot. Per-format
  /// availability is the null check on [banner] / [interstitial] / [rewarded].
  static bool get adsAllowedForThisBuild => !isScreenshotBuild;
}

// ─────────────────────────────────────────────────────────────────────────────
// AdService — singleton managing all ad lifecycle
// ─────────────────────────────────────────────────────────────────────────────
class AdService extends ChangeNotifier {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;
  int _interstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  bool get isInterstitialReady => _isInterstitialReady;
  bool get isRewardedReady => _isRewardedReady;

  // ── Initialize MobileAds SDK ─────────────────────────────────────────────
  Future<void> initialize() async {
    if (kIsWeb) return; // AdMob not supported on web
    // Store-screenshot build: no consent form, no SDK, no ad.
    if (!AdUnitIds.adsAllowedForThisBuild) return;
    // AdMob policy: in the EEA, the UK and Switzerland an ad may not be
    // *requested* until the user has been asked — a non-personalised ad is
    // not a substitute. UMP decides whether a form is required from the
    // user's own location, so there is no geo-check here; everywhere else
    // it reports "not required" and this costs one no-op call.
    await AglConsent.gather();
    await MobileAds.instance.initialize();
    // Caches the answer for AglConsent.adsAllowed, which is what the
    // synchronous ad call sites below read.
    await AglConsent.refresh();
    // Set test device IDs in debug mode
    if (kDebugMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['YOUR_TEST_DEVICE_ID'], // Replace with your device ID
        ),
      );
    }
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  // ── Check if ads should show ─────────────────────────────────────────────
  bool shouldShowAds() {
    if (kIsWeb) return false;
    // A store-screenshot build never shows an ad.
    if (!AdUnitIds.adsAllowedForThisBuild) return false;
    // No ad may be requested until UMP says consent allows it. This is the
    // predicate every caller already checks before createBannerAd(), which
    // returns a non-nullable BannerAd and so cannot decline on its own.
    return AglConsent.adsAllowed;
  }

  // ── Banner Ad Widget ─────────────────────────────────────────────────────
  /// Null when this build has no banner unit (a release build without the
  /// ADMOB_BANNER_* define, or a screenshot build) — request nothing then.
  BannerAd? createBannerAd() {
    final unit = AdUnitIds.banner;
    if (unit == null) return null;
    return BannerAd(
      adUnitId: unit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed: ${error.message}');
        },
      ),
    );
  }

  // ── Interstitial Ad ──────────────────────────────────────────────────────
  void _loadInterstitialAd() {
    // No ad may be requested until UMP says consent allows it.
    if (!AglConsent.adsAllowed) return;
    if (kIsWeb) return;
    if (!AdUnitIds.adsAllowedForThisBuild) return;
    final unit = AdUnitIds.interstitial;
    if (unit == null) return;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _interstitialLoadAttempts = 0;
          ad.setImmersiveMode(true);
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _interstitialLoadAttempts++;
          _isInterstitialReady = false;
          _interstitialAd = null;
          if (_interstitialLoadAttempts < maxFailedLoadAttempts) {
            _loadInterstitialAd();
          }
        },
      ),
    );
  }

  Future<bool> showInterstitialAd() async {
    if (!shouldShowAds()) return false;
    if (!_isInterstitialReady || _interstitialAd == null) return false;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialReady = false;
        _loadInterstitialAd(); // Preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialReady = false;
        _loadInterstitialAd();
      },
    );
    await _interstitialAd!.show();
    _interstitialAd = null;
    return true;
  }

  // ── Rewarded Ad (for unlocking extra exam questions) ─────────────────────
  void _loadRewardedAd() {
    // No ad may be requested until UMP says consent allows it.
    if (!AglConsent.adsAllowed) return;
    if (kIsWeb) return;
    if (!AdUnitIds.adsAllowedForThisBuild) return;
    final unit = AdUnitIds.rewarded;
    if (unit == null) return;
    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _isRewardedReady = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (!_isRewardedReady || _rewardedAd == null) {
      onDismissed?.call();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedReady = false;
        _loadRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isRewardedReady = false;
        _loadRewardedAd();
        onDismissed?.call();
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onRewarded(),
    );
    _rewardedAd = null;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
