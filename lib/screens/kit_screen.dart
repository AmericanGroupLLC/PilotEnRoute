import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The ground tools a renter uses around a flight. Each opens on the dark
/// instrument-panel theme.
class KitScreen extends StatelessWidget {
  const KitScreen({super.key});

  static const tools = <(String, String, String, IconData)>[
    ('/e6b', 'E6B', 'Wind triangle, TAS, density altitude, conversions',
        Icons.calculate_outlined),
    ('/weight-balance', 'Weight & balance', 'CG envelope from your own numbers',
        Icons.balance),
    ('/fuel', 'Fuel', 'Endurance, reserve and a tank timer',
        Icons.local_gas_station_outlined),
    ('/flight-plan', 'Flight planner', 'Legs, headings, times and fuel',
        Icons.route_outlined),
    ('/checklist', 'Checklists', 'Representative only — verify against your '
        'POH/AFM', Icons.checklist),
    ('/documents', 'Documents', 'Certificates and expiry dates (feeds '
        'reminders)', Icons.folder_outlined),
    ('/airport', 'Airport', 'Field details, runways and the latest METAR',
        Icons.local_airport_outlined),
    ('/charts', 'Charts & plates', 'FAA d-TPP terminal procedures (opens '
        'faa.gov)', Icons.map_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Ground tools',
              subtitle: 'For planning on the ground. Not for use in flight.'),
          for (final t in tools)
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(t.$4, color: scheme.primary),
                title: Text(t.$2,
                    style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                subtitle: Text(t.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(t.$1),
              ),
            ),
        ],
      ),
    );
  }
}
