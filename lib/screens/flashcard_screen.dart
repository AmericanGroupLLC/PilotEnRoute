import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../services/flashcard_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlashcardService>().loadCards();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    final service = context.read<FlashcardService>();
    service.flip();
    if (service.isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _next() {
    _flipController.reverse();
    context.read<FlashcardService>().next();
  }

  void _previous() {
    _flipController.reverse();
    context.read<FlashcardService>().previous();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlashcardService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A1628),
          appBar: AppBar(
            title: const Text('FLASHCARDS'),
            actions: [
              IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: () {
                  _flipController.reverse();
                  service.shuffle();
                },
                tooltip: 'Shuffle',
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () => _showStats(context, service),
                tooltip: 'Stats',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildCategoryFilter(service),
              _buildProgressBar(service),
              Expanded(child: _buildCardArea(service)),
              _buildControls(service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter(FlashcardService service) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: service.categories.length,
        itemBuilder: (context, i) {
          final cat = service.categories[i];
          final selected = service.selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              _flipController.reverse();
              service.setCategory(cat);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00BCD4)
                    : const Color(0xFF112240),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00BCD4)
                      : Colors.white24,
                ),
              ),
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(FlashcardService service) {
    final filtered = service.filteredCards;
    if (filtered.isEmpty) return const SizedBox.shrink();
    final progress = (service.currentIndex + 1) / filtered.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '${service.currentIndex + 1} / ${filtered.length}',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00BCD4)),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (service.currentCard != null)
            GestureDetector(
              onTap: () {
                if (service.currentCard != null) {
                  service.toggleStar(service.currentCard!.id);
                }
              },
              child: Icon(
                service.currentCard!.isStarred
                    ? Icons.star
                    : Icons.star_border,
                color: service.currentCard!.isStarred
                    ? const Color(0xFFFFB300)
                    : Colors.white38,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardArea(FlashcardService service) {
    final card = service.currentCard;
    if (card == null) {
      return Center(
        child: Text(
          'No cards in this category',
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      );
    }

    return GestureDetector(
      onTap: _flip,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * math.pi;
            final isFront = angle < math.pi / 2;

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: isFront
                  ? _buildFrontCard(card)
                  : Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildBackCard(card),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrontCard(Flashcard card) {
    final categoryColors = {
      'Aerodynamics': const Color(0xFF00BCD4),
      'Weather': const Color(0xFF2196F3),
      'Regulations': const Color(0xFFFFB300),
      'Navigation': const Color(0xFF4CAF50),
      'Aircraft Systems': const Color(0xFFFF9800),
      'Airspace': const Color(0xFF9C27B0),
      'Emergency': const Color(0xFFF44336),
      'Human Factors': const Color(0xFF00BCD4),
      'IFR': const Color(0xFF3F51B5),
      'Part 107 (Drone)': const Color(0xFF009688),
    };
    final color = categoryColors[card.category] ?? const Color(0xFF00BCD4);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF112240),
            color.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _cardBody(
        children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Text(
                card.category.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: color,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              card.question,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tap to reveal answer',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
            if (card.reference != null) ...[
              const SizedBox(height: 16),
              Text(
                card.reference!,
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: Colors.white24,
                  letterSpacing: 1,
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// The face of a flashcard.
  ///
  /// Centred while the content fits, scrollable when it does not. A folded
  /// phone held in landscape gives the card a very short box, and a long
  /// question plus a large text scale will not fit in it — scrolling the card
  /// face is the right answer there, clipping the question is not.
  Widget _cardBody({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.all(28);
        final minHeight = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight - padding.vertical)
            : 0.0;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackCard(Flashcard card) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A2A), Color(0xFF0D2818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _cardBody(
        children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: Text(
                'ANSWER',
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              card.answer,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            if (card.detail != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  card.detail!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeedbackButton(
                  icon: Icons.close,
                  label: 'Missed',
                  color: const Color(0xFFF44336),
                  onTap: () {
                    _markIncorrect(context, card.id);
                    _next();
                  },
                ),
                _buildFeedbackButton(
                  icon: Icons.check,
                  label: 'Got It',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    _markCorrect(context, card.id);
                    _next();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _markCorrect(BuildContext ctx, String id) {
    ctx.read<FlashcardService>().markCorrect(id);
  }

  void _markIncorrect(BuildContext ctx, String id) {
    ctx.read<FlashcardService>().markIncorrect(id);
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(FlashcardService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _previous,
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
            iconSize: 28,
          ),
          GestureDetector(
            onTap: _flip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.flip, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'FLIP',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Forward',
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  void _showStats(BuildContext context, FlashcardService service) {
    final cards = service.filteredCards;
    final reviewed = cards.where((c) => c.reviewCount > 0).length;
    final avgAccuracy = cards.isEmpty
        ? 0.0
        : cards.fold(0.0, (sum, c) => sum + c.accuracy) / cards.length;
    final starred = cards.where((c) => c.isStarred).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF112240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FLASHCARD STATS',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('Total Cards', '${cards.length}', const Color(0xFF00BCD4)),
                _statItem('Reviewed', '$reviewed', const Color(0xFF4CAF50)),
                _statItem('Accuracy', '${(avgAccuracy * 100).round()}%', const Color(0xFFFFB300)),
                _statItem('Starred', '$starred', const Color(0xFFFF9800)),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
