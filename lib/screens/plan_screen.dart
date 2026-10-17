import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The Plan tab: the Go Card, weather, charts and check history on top, then
/// the ground tools a renter uses around a flight (each opens on the light
/// flight-bag theme).
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

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

  /// "What is this?" for each tool, for pilots still learning what the tools
  /// do. Each one points back to the pilot's own POH/AFM and official
  /// sources rather than replacing them.
  static const explanations = <String, String>{
    '/e6b': 'The E6B is the pilot\'s flight computer, originally a circular '
        'slide rule. It solves the wind triangle (the heading to fly and the '
        'groundspeed for a given course, true airspeed and wind), true '
        'airspeed from indicated airspeed, altitude and temperature, density '
        'altitude, and time, speed, distance and fuel problems. Winds aloft '
        'forecasts are in degrees true, so apply magnetic variation to the '
        'heading before you fly it.',
    '/weight-balance': 'Weight and balance checks that the airplane is under '
        'its maximum weights and that its centre of gravity (CG) is inside '
        'the envelope in the POH/AFM. Each item\'s weight times its arm '
        '(distance from the datum) is its moment; total moment divided by '
        'total weight is the CG. An aft CG makes the airplane less stable '
        'and stall recovery harder; a forward CG raises the stall speed and '
        'makes the nose harder to raise. Use the empty weight and arms from '
        'your aircraft\'s own weight-and-balance record.',
    '/fuel': 'Endurance is usable fuel divided by fuel burn. Under VFR, '
        '14 CFR 91.151 requires enough fuel to reach the first point of '
        'intended landing and then fly at normal cruise for 30 minutes by '
        'day or 45 minutes at night. In IFR conditions, 91.167 requires '
        'fuel to the destination, then to the alternate when one is '
        'required, then 45 minutes. Many pilots keep a larger personal '
        'reserve. The '
        'tank timer reminds you to switch tanks if your airplane needs it.',
    '/flight-plan': 'A navigation log breaks the route into legs. For each '
        'leg: true course from the chart, a wind correction to get true '
        'heading, magnetic variation to get magnetic heading, then '
        'groundspeed, time and fuel. Checkpoints let you confirm position '
        'and groundspeed on the way. This planner does the arithmetic; it '
        'does not file a flight plan (use 1800wxbrief.com or call '
        '1-800-WX-BRIEF).',
    '/checklist': 'Checklists make sure each step of a procedure is done, in '
        'order, every time: preflight, before start, run-up, before takeoff, '
        'landing, shutdown and emergencies. The lists here are '
        'representative examples only. Always use the checklist in your '
        'aircraft\'s POH/AFM.',
    '/documents': 'The pilot carries a pilot certificate, photo ID and a '
        'medical certificate (or, under BasicMed, a valid U.S. driver\'s '
        'licence). The airplane needs its airworthiness certificate, '
        'registration, operating limitations and weight-and-balance data on '
        'board. Keep copies and expiry dates here so reminders arrive in '
        'time. A copy on your phone does not replace a document the '
        'regulations require you to carry.',
    '/airport': 'Airport details from FAA data via the Aviation Weather '
        'Center: identifiers, elevation, runways and their true alignment, '
        'and frequencies. Runway numbers are the magnetic direction rounded '
        'to tens of degrees, so runway 31 points about 310° magnetic. Check '
        'the Chart Supplement and NOTAMs for current information.',
    '/charts': 'Terminal procedures (d-TPP) are the FAA\'s airport diagrams, '
        'instrument approach plates and departure and arrival procedures. '
        'They are reissued every 28 days. This opens the FAA\'s own search '
        'for the current cycle.',
  };

  static void showExplanation(BuildContext context, String route,
      String title) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('About $title'),
              Text(explanations[route] ?? '',
                  style: const TextStyle(fontSize: 15, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }

  /// The four large tiles at the top: route, title, caption, icon.
  static const hubTiles = <(String, String, String, IconData)>[
    ('/go', 'Go Card', 'Legal + minimums', Icons.flight_takeoff_rounded),
    ('/weather', 'Weather', 'METAR · TAF · AIRMET · PIREP', Icons.cloud_outlined),
    ('/charts', 'Charts & plates', 'FAA terminal procedures',
        Icons.map_outlined),
    ('/history', 'Check history', 'Your past Go checks',
        Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final bag = [for (final t in tools) if (t.$1 != '/charts') t];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const PageTitle('Plan',
            subtitle: 'Go Card, weather and your flight bag'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (var r = 0; r < hubTiles.length; r += 2) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _HubTile(hubTiles[r])),
                  const SizedBox(width: 10),
                  Expanded(child: _HubTile(hubTiles[r + 1])),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          const SectionHeader('Flight bag',
              subtitle: 'For planning on the ground. Not for use in flight.'),
          for (final t in bag) ...[
            NavRowCard(
              icon: t.$4,
              title: t.$2,
              subtitle: t.$3,
              onTap: () => Navigator.of(context).pushNamed(t.$1),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'About ${t.$2}',
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () => showExplanation(context, t.$1, t.$2),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile(this.t);
  final (String, String, String, IconData) t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final about = PlanScreen.explanations.containsKey(t.$1);
    return SkyCard(
      key: Key('plan-tile-${t.$1}'),
      onTap: () => Navigator.of(context).pushNamed(t.$1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconTile(t.$4),
            const Spacer(),
            if (about)
              IconButton(
                tooltip: 'About ${t.$2}',
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () =>
                    PlanScreen.showExplanation(context, t.$1, t.$2),
              ),
          ]),
          const SizedBox(height: 14),
          Text(t.$2,
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: scheme.onSurface)),
          const SizedBox(height: 2),
          Text(t.$3,
              style: TextStyle(
                  fontSize: 12.5, height: 1.25, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
