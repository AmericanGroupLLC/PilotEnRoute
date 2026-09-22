import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/premium_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  String _selectedPlan = kYearlyProductId;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PremiumService>().initialize();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        if (premium.isPremium) {
          return _buildAlreadyPremiumScreen(premium);
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      _buildHeroSection(),
                      _buildFeatureList(),
                      _buildPricingCards(premium),
                      _buildCTAButton(premium),
                      _buildRestoreButton(premium),
                      _buildLegalText(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: const Color(0xFF0A0E1A),
      leading: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'PilotEnRoute Premium',
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Gold badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.black, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'UPGRADE TO PREMIUM',
                    style: GoogleFonts.orbitron(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Plane icon with glow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withAlpha(100),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.flight,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Train Like a Pro.\nFly With Confidence.',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock every feature, remove all ads, and access the\ncomplete aviation training platform.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      _FeatureItem(
        icon: Icons.block,
        color: const Color(0xFFFFD700),
        title: 'Ad-Free Experience',
        subtitle: 'Zero interruptions during study sessions',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.quiz,
        color: const Color(0xFF4CAF50),
        title: 'Unlimited Exam Questions',
        subtitle: 'Full access to the live FAA-style question bank',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.flight,
        color: const Color(0xFF2196F3),
        title: 'All Aircraft & Scenarios',
        subtitle: '6 aircraft types, 7 simulation scenarios',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.book,
        color: const Color(0xFF9C27B0),
        title: 'Digital Logbook PDF Export',
        subtitle: 'Export FAA-compliant logbook as PDF',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.cloud,
        color: const Color(0xFF00BCD4),
        title: 'Advanced Weather Data',
        subtitle: 'PIREPs, SIGMETs, AIRMETs, winds aloft',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.map,
        color: const Color(0xFFFF9800),
        title: 'Full Flight Planner',
        subtitle: 'ICAO flight plans with weather integration',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.smart_toy,
        color: const Color(0xFFE91E63),
        title: 'AI Aviation Instructor',
        subtitle: 'Ask any aviation question, get FAA answers',
        free: false,
      ),
      _FeatureItem(
        icon: Icons.wifi_off,
        color: const Color(0xFF607D8B),
        title: 'Offline Mode',
        subtitle: 'Study without internet connection',
        free: false,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1629),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E3A5F),
          width: 1,
        ),
      ),
      child: Column(
        children: features
            .map((f) => _buildFeatureRow(f))
            .toList(),
      ),
    );
  }

  Widget _buildFeatureRow(_FeatureItem feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: feature.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  feature.subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFFD700).withAlpha(80),
              ),
            ),
            child: Text(
              'PREMIUM',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFFFD700),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCards(PremiumService premium) {
    final plans = [
      _PlanCard(
        id: kMonthlyProductId,
        title: 'Monthly',
        price: '\$4.99',
        period: '/month',
        description: 'Cancel anytime',
        badge: '',
        isPopular: false,
      ),
      _PlanCard(
        id: kYearlyProductId,
        title: 'Annual',
        price: '\$34.99',
        period: '/year',
        description: 'Save 42%',
        badge: 'BEST VALUE',
        isPopular: true,
      ),
      _PlanCard(
        id: kLifetimeProductId,
        title: 'Lifetime',
        price: '\$79.99',
        period: 'one-time',
        description: 'Pay once, fly forever',
        badge: 'POPULAR',
        isPopular: false,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Plan',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...plans.map((plan) => _buildPlanCard(plan, premium)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_PlanCard plan, PremiumService premium) {
    final isSelected = _selectedPlan == plan.id;
    final product = premium.products.where((p) => p.id == plan.id).firstOrNull;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFF0F1629),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2196F3)
                : const Color(0xFF1E3A5F),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap so the "BEST VALUE" badge drops under the plan title
                  // on a folded window instead of pushing it off the edge.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        plan.title,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (plan.badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badge,
                            style: GoogleFonts.orbitron(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    plan.description,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white70 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product?.price ?? plan.price,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  plan.period,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTAButton(PremiumService premium) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: premium.isLoading
              ? null
              : () async {
                  final product = premium.products
                      .where((p) => p.id == _selectedPlan)
                      .firstOrNull;
                  if (product != null) {
                    await premium.purchase(product);
                  } else {
                    // Store not available — show message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Store unavailable. Please try again later.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: const Color(0xFFFFD700).withAlpha(80),
          ),
          child: premium.isLoading
              ? const CircularProgressIndicator(color: Colors.black)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'START PREMIUM NOW',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(PremiumService premium) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      // Wrap, not Row: the two links plus the separator are wider than a
      // folded cover display, and wider still at a large text scale.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => premium.restorePurchases(),
            child: Text(
              'Restore Purchases',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white54,
              ),
            ),
          ),
          Text(
            ' · ',
            style: GoogleFonts.inter(color: Colors.white38),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.safecodeg.com/policy/pilotenroute/'),
            ),
            child: Text(
              'Privacy Policy',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalText() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text(
        'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in your device settings.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white30,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAlreadyPremiumScreen(PremiumService premium) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Premium Active',
          style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(80),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.black,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You\'re Premium!',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enjoy all features, ad-free.\nThank you for supporting PilotEnRoute.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1629),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withAlpha(60)),
                ),
                child: Column(
                  children: [
                    _premiumStatusRow(
                        'Plan', premium.tier.name.toUpperCase()),
                    const Divider(color: Color(0xFF1E3A5F)),
                    _premiumStatusRow('Status', 'Active'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(premium.manageSubscriptionUrl);
                  if (await canLaunchUrl(url)) launchUrl(url);
                },
                child: Text(
                  'Manage Subscription',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFD700),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool free;

  _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.free,
  });
}

class _PlanCard {
  final String id;
  final String title;
  final String price;
  final String period;
  final String description;
  final String badge;
  final bool isPopular;

  _PlanCard({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.description,
    required this.badge,
    required this.isPopular,
  });
}
