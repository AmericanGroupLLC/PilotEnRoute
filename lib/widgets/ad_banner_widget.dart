import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdBannerWidget — drop-in banner ad
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
    // No ad will ever be requested while the unit IDs are still Google's
    // test units, so the slot must take up no space at all — the loading
    // placeholder below would otherwise sit there as a permanent grey bar.
    if (!AdUnitIds.adsAllowedForThisBuild) return const SizedBox.shrink();

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
              'Advertisement',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
              'Advertisement',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
}
