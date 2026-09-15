import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';

class ModuleCard extends StatelessWidget {
  final ModuleData data;
  const ModuleCard({super.key, required this.data});

  /// Screen-reader label: the card title is laid out with hard line breaks for
  /// the grid, which a screen reader would otherwise read as a pause mid-name.
  String get _semanticLabel {
    final title = data.title.replaceAll('\n', ' ');
    return data.badge == null ? title : '$title, ${data.badge}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, data.route),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.color,
                data.color.withValues(alpha: 0.6),
                const Color(0xFF112240),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: data.color.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: data.color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                // The grid cell is sized by the window, which on a folding
                // phone changes while the app runs — and the label grows with
                // the user's text scale. scaleDown keeps the tile intact at
                // its natural size and only shrinks it when it genuinely
                // cannot fit, instead of overflowing the cell.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(data.icon, color: Colors.white, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (data.badge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.badge!,
                      style: GoogleFonts.orbitron(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
