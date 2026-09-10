import 'dart:io';
import 'package:agl_ads/agl_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_service.dart';

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

  // ── Check if ads should show (premium users see no ads) ──────────────────
  bool shouldShowAds() {
    if (kIsWeb) return false;
    // No ad may be requested until UMP says consent allows it. This is the
    // predicate every caller already checks before createBannerAd(), which
    // returns a non-nullable BannerAd and so cannot decline on its own.
    if (!AglConsent.adsAllowed) return false;
    return !PremiumService().isPremium;
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
