import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../screens/premium_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumGate — wraps any widget; shows upgrade pop-up when tapped by free user
// ─────────────────────────────────────────────────────────────────────────────
class PremiumGate extends StatelessWidget {
  final Widget child;
  final String feature;
  final String title;
  final String description;

  const PremiumGate({
    super.key,
    required this.child,
    required this.feature,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        if (premium.hasFeature(feature)) return child;
        return GestureDetector(
          onTap: () => _showUpgradeSheet(context, title, description),
          child: Stack(
            children: [
              AbsorbPointer(child: Opacity(opacity: 0.4, child: child)),
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(80),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Colors.black, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'PREMIUM',
                          style: GoogleFonts.orbitron(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PremiumBannerAd — shows AdMob banner for free users, nothing for premium
// ─────────────────────────────────────────────────────────────────────────────
class PremiumAdBanner extends StatefulWidget {
  const PremiumAdBanner({super.key});

  @override
  State<PremiumAdBanner> createState() => _PremiumAdBannerState();
}

class _PremiumAdBannerState extends State<PremiumAdBanner> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        if (premium.isPremium) return const SizedBox.shrink();
        // Show a placeholder banner (real AdMob widget on device)
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1629),
            border: Border(
              top: BorderSide(
                  color: const Color(0xFF1E3A5F).withAlpha(120), width: 1),
              bottom: BorderSide(
                  color: const Color(0xFF1E3A5F).withAlpha(120), width: 1),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(4),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Advertisement — Upgrade to Premium to remove ads',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _showUpgradeSheet(
                  context,
                  'Remove Ads',
                  'Upgrade to Premium for an ad-free experience.',
                ),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFD700),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upgrade bottom sheet — shown contextually when a locked feature is tapped
// ─────────────────────────────────────────────────────────────────────────────
void _showUpgradeSheet(
    BuildContext context, String title, String description) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _UpgradeSheet(
      title: title,
      description: description,
    ),
  );
}

// Public version for use from other screens
void showUpgradePopup(BuildContext context,
    {String title = 'Premium Feature',
    String description = 'Upgrade to Premium to unlock this feature.'}) {
  _showUpgradeSheet(context, title, description);
}

class _UpgradeSheet extends StatelessWidget {
  final String title;
  final String description;

  const _UpgradeSheet({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Lock icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.black,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Feature bullets
          _featureBullet('Remove all ads'),
          _featureBullet('Full exam mode & live FAA-style question bank'),
          _featureBullet('All aircraft & simulation scenarios'),
          _featureBullet('PDF logbook export'),
          _featureBullet('AI Aviation Instructor'),
          const SizedBox(height: 24),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PremiumScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: const Color(0xFFFFD700).withAlpha(80),
              ),
              child: Text(
                'UNLOCK PREMIUM',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
