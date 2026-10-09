import 'dart:io';
import 'package:agl_ads/agl_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ad Unit IDs
// Replace test IDs with real ones from AdMob console before release
// ─────────────────────────────────────────────────────────────────────────────
class AdUnitIds {
  // ── Android ─────────────────────────────────────────────────────────────
  static const String androidBanner =
      'ca-app-pub-3940256099942544/6300978111'; // TEST — replace with real
  static const String androidInterstitial =
      'ca-app-pub-3940256099942544/1033173712'; // TEST — replace with real
  static const String androidRewarded =
      'ca-app-pub-3940256099942544/5224354917'; // TEST — replace with real
  static const String androidNative =
      'ca-app-pub-3940256099942544/2247696110'; // TEST — replace with real

  // ── iOS ──────────────────────────────────────────────────────────────────
  static const String iosBanner =
      'ca-app-pub-3940256099942544/2934735716'; // TEST — replace with real
  static const String iosInterstitial =
      'ca-app-pub-3940256099942544/4411468910'; // TEST — replace with real
  static const String iosRewarded =
      'ca-app-pub-3940256099942544/1712485313'; // TEST — replace with real
  static const String iosNative =
      'ca-app-pub-3940256099942544/3986624511'; // TEST — replace with real

  // ── Getters ──────────────────────────────────────────────────────────────
  static String get banner =>
      Platform.isIOS ? iosBanner : androidBanner;
  static String get interstitial =>
      Platform.isIOS ? iosInterstitial : androidInterstitial;
  static String get rewarded =>
      Platform.isIOS ? iosRewarded : androidRewarded;
  static String get native =>
      Platform.isIOS ? iosNative : androidNative;

  // ── Are these real units? ────────────────────────────────────────────────
  /// AGL's real AdMob publisher. A unit from any other publisher — Google's
  /// public test publisher above, or an uppercase `YOUR_…` placeholder — is not
  /// a real unit and must never be requested outside debug.
  ///
  /// THIS IS THE ONE PLACE TO DROP THE REAL IDS: replace the eight constants
  /// above with the units from AdMob console → Apps → PilotEnRoute → Ad units
  /// and ads switch on automatically, with no other code change, as soon as
  /// they are real `ca-app-pub-8528784688453695/...` ids.
  static const String _realAdPublisher = 'ca-app-pub-8528784688453695';

  static bool _isRealUnit(String id) =>
      id.startsWith('$_realAdPublisher/') && !id.contains('YOUR_');

  /// True only when every unit this app actually requests is a real one.
  /// `native` is deliberately excluded: it is declared but never loaded, so
  /// requiring it would keep ads switched off forever. Add it back here if a
  /// native placement is ever wired up.
  static bool get adUnitsAreReal => const [
        androidBanner,
        iosBanner,
        androidInterstitial,
        iosInterstitial,
        androidRewarded,
        iosRewarded,
      ].every(_isRealUnit);

  /// Whether this build may request an ad at all. Debug builds keep serving the
  /// test units so the integration stays testable; every other build refuses
  /// until [adUnitsAreReal], so a test ad cannot reach a real user.
  static bool get adsAllowedForThisBuild => kDebugMode || adUnitsAreReal;
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
    // Serving Google's test units to a real user is an AdMob policy breach and
    // earns nothing, so a non-debug build declines until real units are in.
    if (!AdUnitIds.adsAllowedForThisBuild) return false;
    // No ad may be requested until UMP says consent allows it. This is the
    // predicate every caller already checks before createBannerAd(), which
    // returns a non-nullable BannerAd and so cannot decline on its own.
    return AglConsent.adsAllowed;
  }

  // ── Banner Ad Widget ─────────────────────────────────────────────────────
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: AdUnitIds.banner,
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
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
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
    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
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
