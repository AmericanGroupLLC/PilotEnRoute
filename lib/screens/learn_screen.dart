import 'package:flutter/material.dart';

import '../ui/sky_scene.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'airport_ops_screen.dart';
import 'library_screen.dart';
import 'six_pack_screen.dart';

/// Learn: ground school from the FAA's own handbooks. Every screen behind it
/// cites the FAA page or paragraph it is taken from.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const PageTitle('Learn',
            subtitle: 'Ground school from the FAA handbooks'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SkyCard(
            padding: EdgeInsets.zero,
            radius: Sky.cornersL,
            child: Stack(children: [
              const SkyScene(height: 120),
              Positioned(
                left: 16,
                bottom: 14,
                right: 100,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest.withValues(alpha: .92),
                    borderRadius: Sky.cornersM,
                  ),
                  child: Text(
                      'Everything here quotes or follows an FAA source, with '
                      'the page.',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Ground school'),
          NavRowCard(
            key: const Key('learn-library'),
            icon: Icons.local_library_outlined,
            title: 'FAA library',
            subtitle: 'PHAK, Airplane Flying Handbook, AIM, weather',
            onTap: () => open(const LibraryScreen()),
          ),
          const SizedBox(height: 10),
          NavRowCard(
            key: const Key('learn-sixpack'),
            icon: Icons.speed_rounded,
            title: 'Six-pack trainer',
            subtitle: 'The six flight instruments · PHAK chapter 8',
            onTap: () => open(const SixPackScreen()),
          ),
          const SizedBox(height: 10),
          NavRowCard(
            key: const Key('learn-airport-ops'),
            icon: Icons.signpost_outlined,
            title: 'Airport operations',
            subtitle: 'Traffic pattern, signs, markings · AIM',
            onTap: () => open(const AirportOpsScreen()),
          ),
        ],
      ),
    );
  }
}
