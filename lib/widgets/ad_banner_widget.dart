import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../services/ad_service.dart';
import '../screens/premium_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdBannerWidget — drop-in banner ad that respects premium status
// Usage: just add AdBannerWidget() anywhere in a screen's Column/body
// ─────────────────────────────────────────────────────────────────────────────
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    final adService = AdService();
    if (!adService.shouldShowAds()) return;

    _bannerAd = adService.createBannerAd()
      ..load().then((_) {
        if (mounted) setState(() => _isAdLoaded = true);
      });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        // Premium users see nothing
        if (premium.isPremium) return const SizedBox.shrink();

        // Web: show styled placeholder
        if (kIsWeb) return _buildWebPlaceholder(context);

        // Mobile: show real AdMob banner or placeholder while loading
        if (_isAdLoaded && _bannerAd != null) {
          return Semantics(
            container: true,
            label: 'Advertisement',
            child: Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          );
        }

        // Loading / fallback placeholder
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1629),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFF1E3A5F).withAlpha(100),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          _adLabel(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upgrade to Premium — Remove Ads & Unlock All Features',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _upgradeButton(context),
        ],
      ),
    );
  }

  Widget _buildWebPlaceholder(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1629),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFF1E3A5F).withAlpha(100),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          _adLabel(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Advertisement — Go Premium for an ad-free experience',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _upgradeButton(context),
        ],
      ),
    );
  }

  Widget _adLabel() {
    return Semantics(
      container: true,
      label: 'Advertisement',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'AD',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _upgradeButton(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Go Premium, remove ads',
      excludeSemantics: true,
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ),
        child: Text(
          'Go Premium',
          style: GoogleFonts.inter(
            color: const Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
