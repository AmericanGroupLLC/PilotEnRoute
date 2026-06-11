import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  String _selectedAircraft = 'Cessna 172';
  String _selectedPhase = 'Preflight';
  Map<String, bool> _checked = {};

  final List<String> _aircraft = [
    'Cessna 172', 'Cessna 182', 'Piper PA-28', 'Beechcraft Bonanza',
    'Cirrus SR22', 'Diamond DA40', 'Piper Seneca', 'Generic IFR',
  ];

  @override
  Widget build(BuildContext context) {
    final phases = _getPhases(_selectedAircraft);
    final items = _getChecklist(_selectedAircraft, _selectedPhase);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('CHECKLISTS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _checked.clear()),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Aircraft selector
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _aircraft.length,
              itemBuilder: (context, i) {
                final ac = _aircraft[i];
                final selected = _selectedAircraft == ac;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedAircraft = ac;
                    _checked.clear();
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF00BCD4) : const Color(0xFF112240),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFF00BCD4) : Colors.white24,
                      ),
                    ),
                    child: Text(
                      ac,
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
          ),
          // Phase tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: phases.length,
              itemBuilder: (context, i) {
                final phase = phases[i];
                final selected = _selectedPhase == phase['name'];
                final color = phase['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedPhase = phase['name'] as String;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.2) : const Color(0xFF112240),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(phase['icon'] as IconData, color: selected ? color : Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          phase['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? color : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_checked.values.where((v) => v).length} / ${items.length}',
                  style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: items.isEmpty ? 0 : _checked.values.where((v) => v).length / items.length,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Checklist items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final key = '${_selectedAircraft}_${_selectedPhase}_$i';
                final isChecked = _checked[key] ?? false;

                if (item['type'] == 'header') {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Text(
                      item['text'] as String,
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: const Color(0xFF00BCD4),
                        letterSpacing: 2,
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => setState(() => _checked[key] = !isChecked),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : const Color(0xFF112240),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked
                            ? const Color(0xFF4CAF50).withOpacity(0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isChecked
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isChecked
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white38,
                              width: 2,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(Icons.check, color: Colors.black, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['action'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isChecked ? Colors.white54 : Colors.white,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item['value'] != null)
                                Text(
                                  item['value'] as String,
                                  style: GoogleFonts.orbitron(
                                    fontSize: 10,
                                    color: isChecked
                                        ? Colors.white24
                                        : const Color(0xFF00BCD4),
                                    letterSpacing: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item['critical'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF44336).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CRITICAL',
                              style: GoogleFonts.orbitron(
                                fontSize: 7,
                                color: const Color(0xFFF44336),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPhases(String aircraft) {
    return [
      {'name': 'Preflight', 'icon': Icons.search, 'color': const Color(0xFF2196F3)},
      {'name': 'Before Start', 'icon': Icons.power_settings_new, 'color': const Color(0xFFFFB300)},
      {'name': 'Engine Start', 'icon': Icons.settings, 'color': const Color(0xFFFF9800)},
      {'name': 'Before Taxi', 'icon': Icons.directions_car, 'color': const Color(0xFF9C27B0)},
      {'name': 'Run-Up', 'icon': Icons.speed, 'color': const Color(0xFF4CAF50)},
      {'name': 'Before Takeoff', 'icon': Icons.flight_takeoff, 'color': const Color(0xFF00BCD4)},
      {'name': 'Cruise', 'icon': Icons.flight, 'color': const Color(0xFF3F51B5)},
      {'name': 'Descent', 'icon': Icons.flight_land, 'color': const Color(0xFFFF5722)},
      {'name': 'Landing', 'icon': Icons.flight_land, 'color': const Color(0xFFF44336)},
      {'name': 'Shutdown', 'icon': Icons.power_off, 'color': const Color(0xFF607D8B)},
    ];
  }

  List<Map<String, dynamic>> _getChecklist(String aircraft, String phase) {
    final checklists = <String, List<Map<String, dynamic>>>{
      'Preflight': [
        {'type': 'header', 'text': 'DOCUMENTS'},
        {'action': 'Airworthiness Certificate', 'value': 'CHECK - IN AIRCRAFT'},
        {'action': 'Registration', 'value': 'CHECK - IN AIRCRAFT'},
        {'action': 'POH / AFM', 'value': 'CHECK - IN AIRCRAFT'},
        {'action': 'Weight & Balance', 'value': 'CHECK - CURRENT'},
        {'type': 'header', 'text': 'FUEL & OIL'},
        {'action': 'Fuel Quantity', 'value': 'CHECK VISUALLY', 'critical': true},
        {'action': 'Fuel Caps', 'value': 'SECURE', 'critical': true},
        {'action': 'Fuel Sumps', 'value': 'DRAIN & CHECK - CLEAR'},
        {'action': 'Oil Level', 'value': '6-8 QUARTS', 'critical': true},
        {'action': 'Oil Cap', 'value': 'SECURE'},
        {'type': 'header', 'text': 'EXTERIOR INSPECTION'},
        {'action': 'Pitot Tube Cover', 'value': 'REMOVE', 'critical': true},
        {'action': 'Pitot Tube', 'value': 'CLEAR - UNOBSTRUCTED'},
        {'action': 'Static Ports', 'value': 'CLEAR'},
        {'action': 'Control Surfaces', 'value': 'FREE & CORRECT'},
        {'action': 'Tires', 'value': 'CHECK - PROPER INFLATION'},
        {'action': 'Brakes', 'value': 'CHECK - NO LEAKS'},
        {'action': 'Lights', 'value': 'CHECK - OPERATIONAL'},
        {'action': 'Antennas', 'value': 'CHECK - SECURE'},
        {'action': 'ELT', 'value': 'ARMED - SECURE'},
        {'action': 'Chocks/Tie-Downs', 'value': 'REMOVE'},
      ],
      'Before Start': [
        {'action': 'Seats & Seat Belts', 'value': 'ADJUST & SECURE'},
        {'action': 'Brakes', 'value': 'TEST & SET'},
        {'action': 'Circuit Breakers', 'value': 'CHECK - IN'},
        {'action': 'Fuel Selector', 'value': 'BOTH', 'critical': true},
        {'action': 'Mixture', 'value': 'RICH'},
        {'action': 'Primer', 'value': 'IN & LOCKED'},
        {'action': 'Avionics Master', 'value': 'OFF'},
        {'action': 'Electrical Equipment', 'value': 'OFF'},
      ],
      'Engine Start': [
        {'action': 'Throttle', 'value': '1/4 INCH OPEN'},
        {'action': 'Mixture', 'value': 'RICH', 'critical': true},
        {'action': 'Master Switch', 'value': 'ON'},
        {'action': 'Beacon', 'value': 'ON'},
        {'action': 'Area', 'value': 'CLEAR - ANNOUNCE "CLEAR PROP"', 'critical': true},
        {'action': 'Ignition', 'value': 'START'},
        {'action': 'Oil Pressure', 'value': 'CHECK - GREEN ARC', 'critical': true},
        {'action': 'Throttle', 'value': '1000 RPM'},
        {'action': 'Avionics Master', 'value': 'ON'},
        {'action': 'Radios', 'value': 'SET'},
      ],
      'Run-Up': [
        {'action': 'Brakes', 'value': 'HOLD', 'critical': true},
        {'action': 'Throttle', 'value': '1800 RPM'},
        {'action': 'Magnetos', 'value': 'CHECK - DROP < 125 RPM, DIFF < 50 RPM', 'critical': true},
        {'action': 'Carb Heat', 'value': 'CHECK - RPM DROP THEN RISE'},
        {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
        {'action': 'Ammeter', 'value': 'CHECK - POSITIVE'},
        {'action': 'Suction Gauge', 'value': '4.8 - 5.1 IN HG'},
        {'action': 'Throttle', 'value': '1000 RPM'},
        {'action': 'Mixture', 'value': 'RICH (< 3000 ft)'},
      ],
      'Before Takeoff': [
        {'action': 'Transponder', 'value': 'ALT', 'critical': true},
        {'action': 'Lights', 'value': 'ON - STROBES, LANDING LIGHT'},
        {'action': 'Fuel Selector', 'value': 'BOTH', 'critical': true},
        {'action': 'Mixture', 'value': 'RICH', 'critical': true},
        {'action': 'Elevator Trim', 'value': 'SET FOR TAKEOFF'},
        {'action': 'Flaps', 'value': 'SET PER POH'},
        {'action': 'Doors & Windows', 'value': 'CLOSED & LATCHED'},
        {'action': 'Seat Belts', 'value': 'FASTENED', 'critical': true},
        {'action': 'ATIS/AWOS', 'value': 'CURRENT'},
        {'action': 'Runways & Taxiways', 'value': 'CLEAR', 'critical': true},
      ],
      'Cruise': [
        {'action': 'Power', 'value': 'SET - 65-75% CRUISE'},
        {'action': 'Mixture', 'value': 'LEAN AS REQUIRED'},
        {'action': 'Fuel Selector', 'value': 'CHECK - BOTH OR FULLEST'},
        {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
        {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
        {'action': 'Heading', 'value': 'CHECK - ON COURSE'},
        {'action': 'Fuel Remaining', 'value': 'CHECK - ADEQUATE RESERVE'},
      ],
      'Descent': [
        {'action': 'ATIS/AWOS', 'value': 'OBTAIN - DESTINATION'},
        {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
        {'action': 'Mixture', 'value': 'RICHEN AS REQUIRED'},
        {'action': 'Carb Heat', 'value': 'AS REQUIRED'},
        {'action': 'Fuel Selector', 'value': 'BOTH'},
        {'action': 'Lights', 'value': 'AS REQUIRED'},
        {'action': 'Seat Belts', 'value': 'FASTEN'},
      ],
      'Landing': [
        {'action': 'Fuel Selector', 'value': 'BOTH', 'critical': true},
        {'action': 'Mixture', 'value': 'RICH', 'critical': true},
        {'action': 'Carb Heat', 'value': 'ON - BELOW 2500 RPM'},
        {'action': 'Flaps', 'value': 'SET PER POH'},
        {'action': 'Airspeed', 'value': 'VREF PER POH'},
        {'action': 'Runway', 'value': 'CLEAR', 'critical': true},
        {'action': 'Transponder', 'value': 'ALT'},
      ],
      'Shutdown': [
        {'action': 'Throttle', 'value': '1000 RPM - COOL DOWN'},
        {'action': 'Avionics Master', 'value': 'OFF'},
        {'action': 'Mixture', 'value': 'IDLE CUTOFF', 'critical': true},
        {'action': 'Ignition', 'value': 'OFF - ENGINE STOPPED'},
        {'action': 'Master Switch', 'value': 'OFF'},
        {'action': 'Fuel Selector', 'value': 'OFF'},
        {'action': 'Control Lock', 'value': 'INSTALL'},
        {'action': 'Pitot Cover', 'value': 'INSTALL'},
        {'action': 'Tie-Downs', 'value': 'SECURE'},
        {'action': 'Logbook', 'value': 'COMPLETE ENTRY'},
      ],
    };

    return checklists[phase] ?? [];
  }
}
