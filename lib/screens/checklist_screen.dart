import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: The checklists below are REPRESENTATIVE / for demonstration only.
// They are a reasonable approximation of common single-engine procedures and
// are NOT a substitute for the manufacturer's approved checklist. Pilots MUST
// verify every item against the specific aircraft's POH / AFM before flight.
// Where an aircraft has no type-specific content for a given phase, the app
// falls back to a sensible generic set (see `_getChecklist`).

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  String _selectedAircraft = 'Cessna 172';
  String _selectedPhase = 'Preflight';

  // Checked state, keyed by a STABLE key (see `_currentItems`) so it survives
  // navigation, phase/aircraft switches and app restarts. Persisted as JSON.
  final Map<String, bool> _checked = {};

  // User-added custom items, keyed by '<aircraft>|<phase>'. Each entry is a
  // list of {id, action, value}. Persisted under 'checklist_custom_' keys.
  final Map<String, List<Map<String, dynamic>>> _custom = {};

  SharedPreferences? _prefs;

  static const String _checkedPrefsKey = 'checklist_checked_state';
  static const String _customPrefsPrefix = 'checklist_custom_';

  final List<String> _aircraft = [
    'Cessna 172', 'Cessna 182', 'Piper PA-28', 'Beechcraft Bonanza',
    'Cirrus SR22', 'Diamond DA40', 'Piper Seneca', 'Generic IFR',
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String get _mapKey => '$_selectedAircraft|$_selectedPhase';

  String _customPrefsKey(String aircraft, String phase) =>
      '$_customPrefsPrefix$aircraft|$phase';

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Restore all checked state.
    final checkedStr = prefs.getString(_checkedPrefsKey);
    final restoredChecked = <String, bool>{};
    if (checkedStr != null && checkedStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(checkedStr);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is bool) restoredChecked['$k'] = v;
          });
        }
      } catch (_) {
        // Corrupt data — ignore and start fresh.
      }
    }

    setState(() {
      _prefs = prefs;
      _checked
        ..clear()
        ..addAll(restoredChecked);
    });

    await _loadCustomForCurrent();
  }

  Future<void> _loadCustomForCurrent() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (_custom.containsKey(_mapKey)) return; // already loaded this session

    final str = prefs.getString(_customPrefsKey(_selectedAircraft, _selectedPhase));
    final list = <Map<String, dynamic>>[];
    if (str != null && str.isNotEmpty) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              list.add({
                'id': '${e['id'] ?? DateTime.now().microsecondsSinceEpoch}',
                'action': '${e['action'] ?? ''}',
                'value': e['value'] == null ? null : '${e['value']}',
              });
            }
          }
        }
      } catch (_) {
        // Corrupt data — ignore.
      }
    }

    if (!mounted) return;
    setState(() => _custom[_mapKey] = list);
  }

  Future<void> _saveChecked() async {
    await _prefs?.setString(_checkedPrefsKey, jsonEncode(_checked));
  }

  Future<void> _saveCustomForCurrent() async {
    await _prefs?.setString(
      _customPrefsKey(_selectedAircraft, _selectedPhase),
      jsonEncode(_custom[_mapKey] ?? const []),
    );
  }

  // Builds the combined (built-in + custom) item list for the current
  // aircraft/phase, tagging each item with a STABLE `key` used for persistence.
  List<Map<String, dynamic>> _currentItems() {
    final aircraft = _selectedAircraft;
    final phase = _selectedPhase;
    final result = <Map<String, dynamic>>[];

    final builtins = _getChecklist(aircraft, phase);
    for (var i = 0; i < builtins.length; i++) {
      final item = Map<String, dynamic>.from(builtins[i]);
      item['key'] = 'b|$aircraft|$phase|$i';
      result.add(item);
    }

    final customs = _custom[_mapKey] ?? const [];
    for (final c in customs) {
      result.add({
        'action': c['action'],
        'value': c['value'],
        'custom': true,
        'id': c['id'],
        'key': 'c|$aircraft|$phase|${c['id']}',
      });
    }
    return result;
  }

  void _toggle(String key, bool current) {
    setState(() => _checked[key] = !current);
    _saveChecked();
  }

  void _resetCurrentPhase() {
    setState(() {
      for (final item in _currentItems()) {
        _checked.remove(item['key']);
      }
    });
    _saveChecked();
  }

  Future<void> _addCustomItem() async {
    final actionController = TextEditingController();
    final valueController = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF112240),
            title: Text(
              'ADD ITEM',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: actionController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Action (required)',
                    labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00BCD4)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Value (optional)',
                    labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00BCD4)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('ADD', style: GoogleFonts.inter(color: const Color(0xFF00BCD4))),
              ),
            ],
          );
        },
      );

      if (result != true) return;
      final action = actionController.text.trim();
      if (action.isEmpty) return; // never crash / add empty input
      final rawValue = valueController.text.trim();

      if (!mounted) return;
      setState(() {
        final list = _custom[_mapKey] ?? <Map<String, dynamic>>[];
        list.add({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'action': action,
          'value': rawValue.isEmpty ? null : rawValue,
        });
        _custom[_mapKey] = list;
      });
      await _saveCustomForCurrent();
    } finally {
      actionController.dispose();
      valueController.dispose();
    }
  }

  void _deleteCustomItem(Map<String, dynamic> item) {
    setState(() {
      final list = _custom[_mapKey];
      if (list != null) {
        list.removeWhere((e) => e['id'] == item['id']);
      }
      _checked.remove(item['key']);
    });
    _saveCustomForCurrent();
    _saveChecked();
  }

  @override
  Widget build(BuildContext context) {
    final phases = _getPhases(_selectedAircraft);
    final items = _currentItems();
    final checkableItems = items.where((it) => it['type'] != 'header').toList();
    final doneCount =
        checkableItems.where((it) => _checked[it['key']] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('CHECKLISTS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetCurrentPhase,
            tooltip: 'Reset phase',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00BCD4),
        onPressed: _addCustomItem,
        tooltip: 'Add custom item',
        child: const Icon(Icons.add, color: Colors.black),
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
                  onTap: () {
                    setState(() => _selectedAircraft = ac);
                    _loadCustomForCurrent();
                  },
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
                  onTap: () {
                    setState(() => _selectedPhase = phase['name'] as String);
                    _loadCustomForCurrent();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF112240),
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
                  '$doneCount / ${checkableItems.length}',
                  style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: checkableItems.isEmpty ? 0 : doneCount / checkableItems.length,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Disclaimer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              'Representative only — always verify against your aircraft POH/AFM.',
              style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
            ),
          ),
          // Checklist items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final key = item['key'] as String;
                final isChecked = _checked[key] ?? false;
                final isCustom = item['custom'] == true;

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
                  onTap: () => _toggle(key, isChecked),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : const Color(0xFF112240),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
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
                        if (isCustom)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CUSTOM',
                              style: GoogleFonts.orbitron(
                                fontSize: 7,
                                color: const Color(0xFF00BCD4),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        if (item['critical'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF44336).withValues(alpha: 0.15),
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
                        if (isCustom)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: 'Delete',
                            onPressed: () => _deleteCustomItem(item),
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

  // Returns the built-in checklist for a given aircraft + phase.
  //
  // Type-specific content is provided for the Cessna 172, Piper PA-28 and
  // Cirrus SR22. Any other aircraft (Cessna 182, Bonanza, DA40, Seneca,
  // Generic IFR, ...) uses the generic default set. If a specific aircraft is
  // missing a particular phase, it also falls back to the generic default for
  // that phase. All content is REPRESENTATIVE — verify against the POH/AFM.
  List<Map<String, dynamic>> _getChecklist(String aircraft, String phase) {
    Map<String, List<Map<String, dynamic>>>? specific;
    switch (aircraft) {
      case 'Cessna 172':
        specific = _c172Checklists;
        break;
      case 'Piper PA-28':
        specific = _pa28Checklists;
        break;
      case 'Cirrus SR22':
        specific = _sr22Checklists;
        break;
      default:
        specific = null; // use generic default below
    }

    return specific?[phase] ?? _defaultChecklists[phase] ?? const [];
  }

  // ---------------------------------------------------------------------------
  // REPRESENTATIVE CHECKLISTS (verify against POH/AFM)
  // ---------------------------------------------------------------------------

  // Cessna 172 (carbureted O-320, fuel selector BOTH, high wing).
  static final Map<String, List<Map<String, dynamic>>> _c172Checklists = {
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
    'Before Taxi': [
      {'action': 'Avionics', 'value': 'ON & SET'},
      {'action': 'Flight Instruments', 'value': 'CHECK - NO FLAGS'},
      {'action': 'Heading Indicator', 'value': 'SET TO COMPASS'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Flaps', 'value': 'UP'},
      {'action': 'ATIS / Clearance', 'value': 'OBTAIN'},
      {'action': 'Brakes', 'value': 'CHECK ON ROLL', 'critical': true},
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

  // Piper PA-28 (low wing, LEFT/RIGHT tank selector — NO "BOTH", electric
  // auxiliary fuel pump, single cabin door, Johnson-bar manual flaps).
  static final Map<String, List<Map<String, dynamic>>> _pa28Checklists = {
    'Preflight': [
      {'type': 'header', 'text': 'DOCUMENTS'},
      {'action': 'Airworthiness Certificate', 'value': 'CHECK - IN AIRCRAFT'},
      {'action': 'Registration', 'value': 'CHECK - IN AIRCRAFT'},
      {'action': 'POH / AFM', 'value': 'CHECK - IN AIRCRAFT'},
      {'action': 'Weight & Balance', 'value': 'CHECK - CURRENT'},
      {'type': 'header', 'text': 'FUEL & OIL'},
      {'action': 'Fuel Quantity', 'value': 'LEFT & RIGHT TANKS', 'critical': true},
      {'action': 'Fuel Caps', 'value': 'SECURE', 'critical': true},
      {'action': 'Fuel Sumps', 'value': 'DRAIN BOTH TANKS + GASCOLATOR'},
      {'action': 'Fuel Vents', 'value': 'CLEAR - UNOBSTRUCTED'},
      {'action': 'Oil Level', 'value': '6-8 QUARTS', 'critical': true},
      {'type': 'header', 'text': 'EXTERIOR INSPECTION'},
      {'action': 'Pitot Cover', 'value': 'REMOVE', 'critical': true},
      {'action': 'Pitot / Static', 'value': 'CLEAR'},
      {'action': 'Stall Warning Vane', 'value': 'CHECK - FREE'},
      {'action': 'Stabilator', 'value': 'FREE & SECURE - CHECK TRIM TAB'},
      {'action': 'Control Surfaces', 'value': 'FREE & CORRECT'},
      {'action': 'Tires', 'value': 'CHECK - PROPER INFLATION'},
      {'action': 'Lights', 'value': 'CHECK - OPERATIONAL'},
      {'action': 'Tie-Downs / Chocks', 'value': 'REMOVE'},
    ],
    'Before Start': [
      {'action': 'Seats & Seat Belts', 'value': 'ADJUST & SECURE'},
      {'action': 'Parking Brake', 'value': 'SET'},
      {'action': 'Circuit Breakers', 'value': 'CHECK - IN'},
      {'action': 'Fuel Selector', 'value': 'DESIRED TANK (FULLEST)', 'critical': true},
      {'action': 'Carb Heat', 'value': 'COLD'},
      {'action': 'Mixture', 'value': 'RICH'},
      {'action': 'Avionics Master', 'value': 'OFF'},
      {'action': 'Electrical Equipment', 'value': 'OFF'},
    ],
    'Engine Start': [
      {'action': 'Throttle', 'value': '1/4 INCH OPEN'},
      {'action': 'Mixture', 'value': 'RICH', 'critical': true},
      {'action': 'Master Switch', 'value': 'ON'},
      {'action': 'Beacon', 'value': 'ON'},
      {'action': 'Electric Fuel Pump', 'value': 'ON - CHECK PRESSURE', 'critical': true},
      {'action': 'Area', 'value': 'CLEAR - ANNOUNCE "CLEAR PROP"', 'critical': true},
      {'action': 'Ignition', 'value': 'START'},
      {'action': 'Oil Pressure', 'value': 'CHECK - GREEN ARC', 'critical': true},
      {'action': 'Electric Fuel Pump', 'value': 'OFF - VERIFY PRESSURE HOLDS'},
      {'action': 'Throttle', 'value': '1000 RPM'},
      {'action': 'Avionics Master', 'value': 'ON'},
    ],
    'Before Taxi': [
      {'action': 'Electric Fuel Pump', 'value': 'OFF - PRESSURE STABLE'},
      {'action': 'Flight Instruments', 'value': 'CHECK - NO FLAGS'},
      {'action': 'Heading Indicator', 'value': 'SET TO COMPASS'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Flaps', 'value': 'UP (JOHNSON BAR)'},
      {'action': 'Radios', 'value': 'SET'},
      {'action': 'Brakes', 'value': 'CHECK ON ROLL', 'critical': true},
    ],
    'Run-Up': [
      {'action': 'Brakes', 'value': 'HOLD', 'critical': true},
      {'action': 'Throttle', 'value': '2000 RPM'},
      {'action': 'Magnetos', 'value': 'CHECK - DROP < 175 RPM, DIFF < 50 RPM', 'critical': true},
      {'action': 'Carb Heat', 'value': 'CHECK - RPM DROP'},
      {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
      {'action': 'Ammeter / Alternator', 'value': 'CHECK'},
      {'action': 'Vacuum / Suction', 'value': 'IN RANGE'},
      {'action': 'Throttle', 'value': '1000 RPM'},
    ],
    'Before Takeoff': [
      {'action': 'Fuel Selector', 'value': 'PROPER TANK (FULLEST)', 'critical': true},
      {'action': 'Electric Fuel Pump', 'value': 'ON', 'critical': true},
      {'action': 'Mixture', 'value': 'RICH', 'critical': true},
      {'action': 'Flaps', 'value': 'SET PER POH'},
      {'action': 'Elevator Trim', 'value': 'SET FOR TAKEOFF'},
      {'action': 'Cabin Door', 'value': 'CLOSED & LATCHED', 'critical': true},
      {'action': 'Seat Belts', 'value': 'FASTENED', 'critical': true},
      {'action': 'Transponder', 'value': 'ALT'},
      {'action': 'Lights', 'value': 'ON - STROBES, LANDING LIGHT'},
      {'action': 'Runways & Taxiways', 'value': 'CLEAR', 'critical': true},
    ],
    'Cruise': [
      {'action': 'Power', 'value': 'SET - 55-75% CRUISE'},
      {'action': 'Electric Fuel Pump', 'value': 'OFF'},
      {'action': 'Mixture', 'value': 'LEAN AS REQUIRED'},
      {'action': 'Fuel Selector', 'value': 'SWITCH TANKS PERIODICALLY'},
      {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Fuel Remaining', 'value': 'CHECK - ADEQUATE RESERVE'},
    ],
    'Descent': [
      {'action': 'ATIS/AWOS', 'value': 'OBTAIN - DESTINATION'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Mixture', 'value': 'RICHEN AS REQUIRED'},
      {'action': 'Fuel Selector', 'value': 'FULLEST TANK'},
      {'action': 'Electric Fuel Pump', 'value': 'ON'},
      {'action': 'Seat Belts', 'value': 'FASTEN'},
    ],
    'Landing': [
      {'action': 'Fuel Selector', 'value': 'PROPER TANK (FULLEST)', 'critical': true},
      {'action': 'Electric Fuel Pump', 'value': 'ON', 'critical': true},
      {'action': 'Mixture', 'value': 'RICH', 'critical': true},
      {'action': 'Carb Heat', 'value': 'AS REQUIRED'},
      {'action': 'Flaps', 'value': 'SET (JOHNSON BAR) PER POH'},
      {'action': 'Airspeed', 'value': 'VREF PER POH'},
      {'action': 'Runway', 'value': 'CLEAR', 'critical': true},
    ],
    'Shutdown': [
      {'action': 'Throttle', 'value': '1000 RPM - COOL DOWN'},
      {'action': 'Electric Fuel Pump', 'value': 'OFF'},
      {'action': 'Radios / Avionics', 'value': 'OFF'},
      {'action': 'Mixture', 'value': 'IDLE CUTOFF', 'critical': true},
      {'action': 'Ignition', 'value': 'OFF - ENGINE STOPPED'},
      {'action': 'Master Switch', 'value': 'OFF'},
      {'action': 'Fuel Selector', 'value': 'OFF'},
      {'action': 'Pitot Cover', 'value': 'INSTALL'},
      {'action': 'Tie-Downs', 'value': 'SECURE'},
    ],
  };

  // Cirrus SR22 (fuel injected — NO carb heat, CAPS airframe parachute,
  // dual battery/alternator, side yoke, glass PFD/MFD, LEFT/RIGHT selector).
  static final Map<String, List<Map<String, dynamic>>> _sr22Checklists = {
    'Preflight': [
      {'type': 'header', 'text': 'DOCUMENTS'},
      {'action': 'ARROW Documents', 'value': 'CHECK - ABOARD'},
      {'action': 'POH / AFM', 'value': 'CHECK - IN AIRCRAFT'},
      {'action': 'Weight & Balance', 'value': 'CHECK - CURRENT'},
      {'type': 'header', 'text': 'CAPS'},
      {'action': 'CAPS Handle Safety Pin', 'value': 'REMOVE', 'critical': true},
      {'action': 'CAPS Placard / Repack Date', 'value': 'CHECK - CURRENT'},
      {'type': 'header', 'text': 'FUEL & OIL'},
      {'action': 'Fuel Quantity', 'value': 'LEFT & RIGHT TANKS', 'critical': true},
      {'action': 'Fuel Caps', 'value': 'SECURE', 'critical': true},
      {'action': 'Fuel Sumps', 'value': 'DRAIN & CHECK - CLEAR'},
      {'action': 'Oil Level', 'value': '6-8 QUARTS', 'critical': true},
      {'type': 'header', 'text': 'EXTERIOR INSPECTION'},
      {'action': 'Pitot Cover', 'value': 'REMOVE', 'critical': true},
      {'action': 'Pitot Heat / Static', 'value': 'CLEAR'},
      {'action': 'Alternate Static', 'value': 'CHECK'},
      {'action': 'Control Surfaces', 'value': 'FREE & CORRECT'},
      {'action': 'Stall Warning', 'value': 'CHECK'},
      {'action': 'Tires & Brakes', 'value': 'CHECK'},
      {'action': 'Nav / Strobe Lights', 'value': 'CHECK'},
      {'action': 'Tie-Downs / Chocks', 'value': 'REMOVE'},
    ],
    'Before Start': [
      {'action': 'Seats & 4-Point Belts', 'value': 'ADJUST & SECURE'},
      {'action': 'Brakes', 'value': 'SET'},
      {'action': 'Fuel Selector', 'value': 'LEFT or RIGHT (FULLEST)', 'critical': true},
      {'action': 'BAT 1 & BAT 2', 'value': 'ON'},
      {'action': 'Avionics (PFD/MFD)', 'value': 'BOOT & CHECK'},
      {'action': 'Circuit Breakers', 'value': 'CHECK - IN'},
      {'action': 'Mixture', 'value': 'FULL RICH'},
    ],
    'Engine Start': [
      {'action': 'Throttle', 'value': 'OPEN 1/4 INCH'},
      {'action': 'Mixture', 'value': 'FULL RICH', 'critical': true},
      {'action': 'Boost Pump', 'value': 'PRIME (HIGH) THEN NORM', 'critical': true},
      {'action': 'BAT / Master', 'value': 'ON'},
      {'action': 'Beacon', 'value': 'ON'},
      {'action': 'Area', 'value': 'CLEAR - ANNOUNCE "CLEAR PROP"', 'critical': true},
      {'action': 'Ignition', 'value': 'START'},
      {'action': 'Oil Pressure', 'value': 'CHECK - GREEN ARC', 'critical': true},
      {'action': 'Throttle', 'value': '1000 RPM'},
      {'action': 'ALT 1 & ALT 2', 'value': 'ON - CHECK'},
    ],
    'Before Taxi': [
      {'action': 'Flaps', 'value': '0%'},
      {'action': 'Flight Instruments (PFD)', 'value': 'CHECK - NO FLAGS'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Autopilot', 'value': 'TEST'},
      {'action': 'Flight Controls', 'value': 'FREE & CORRECT'},
      {'action': 'Brakes', 'value': 'CHECK ON ROLL', 'critical': true},
    ],
    'Run-Up': [
      {'action': 'Brakes', 'value': 'HOLD', 'critical': true},
      {'action': 'Throttle', 'value': '1700 RPM'},
      {'action': 'Magnetos', 'value': 'CHECK - DROP < 150 RPM, DIFF < 75 RPM', 'critical': true},
      {'action': 'Alternate Air', 'value': 'CHECK'},
      {'action': 'Engine Parameters', 'value': 'GREEN ARC'},
      {'action': 'ALT 1 / ALT 2 Loads', 'value': 'CHECK'},
      {'action': 'Throttle', 'value': '1000 RPM'},
    ],
    'Before Takeoff': [
      {'action': 'CAPS', 'value': 'ARMED - PIN VERIFIED REMOVED', 'critical': true},
      {'action': 'Fuel Selector', 'value': 'FULLEST TANK', 'critical': true},
      {'action': 'Mixture', 'value': 'SET FOR TAKEOFF', 'critical': true},
      {'action': 'Flaps', 'value': '50% (PER POH)'},
      {'action': 'Trim', 'value': 'SET FOR TAKEOFF'},
      {'action': 'Doors', 'value': 'CLOSED & LATCHED', 'critical': true},
      {'action': 'Seat Belts', 'value': 'SECURE', 'critical': true},
      {'action': 'Transponder', 'value': 'ALT'},
      {'action': 'Lights', 'value': 'ON'},
      {'action': 'Autopilot', 'value': 'OFF'},
    ],
    'Cruise': [
      {'action': 'Power', 'value': 'SET (% PER POH)'},
      {'action': 'Mixture', 'value': 'LEAN (LOP/ROP PER POH)'},
      {'action': 'Fuel Selector', 'value': 'SWITCH TANKS - KEEP BALANCED'},
      {'action': 'Engine Parameters', 'value': 'GREEN ARC'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Oxygen', 'value': 'AS REQUIRED (> 12,500 ft)'},
      {'action': 'Fuel Remaining', 'value': 'CHECK - ADEQUATE RESERVE'},
    ],
    'Descent': [
      {'action': 'ATIS/AWOS', 'value': 'OBTAIN - DESTINATION'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Mixture', 'value': 'RICHEN AS REQUIRED'},
      {'action': 'Fuel Selector', 'value': 'FULLEST TANK'},
      {'action': 'Landing Light', 'value': 'ON'},
      {'action': 'Seat Belts', 'value': 'FASTEN'},
    ],
    'Landing': [
      {'action': 'Fuel Selector', 'value': 'FULLEST TANK', 'critical': true},
      {'action': 'Mixture', 'value': 'FULL RICH', 'critical': true},
      {'action': 'Flaps', 'value': '100% (PER POH)'},
      {'action': 'Airspeed', 'value': 'VREF PER POH'},
      {'action': 'Autopilot', 'value': 'OFF', 'critical': true},
      {'action': 'Runway', 'value': 'CLEAR', 'critical': true},
    ],
    'Shutdown': [
      {'action': 'Throttle', 'value': 'IDLE - COOL DOWN'},
      {'action': 'Avionics', 'value': 'OFF'},
      {'action': 'Mixture', 'value': 'IDLE CUTOFF', 'critical': true},
      {'action': 'Ignition', 'value': 'OFF - ENGINE STOPPED'},
      {'action': 'ALT 1 / ALT 2 / BAT', 'value': 'OFF'},
      {'action': 'Fuel Selector', 'value': 'AS REQUIRED'},
      {'action': 'CAPS Handle Pin', 'value': 'INSTALL'},
      {'action': 'Pitot Cover', 'value': 'INSTALL'},
    ],
  };

  // Generic single-engine default used by any aircraft without a type-specific
  // list, and as the per-phase fallback for aircraft missing a phase. Wording
  // is intentionally POH-referencing since exact values vary by type.
  static final Map<String, List<Map<String, dynamic>>> _defaultChecklists = {
    'Preflight': [
      {'type': 'header', 'text': 'DOCUMENTS'},
      {'action': 'Aircraft Documents (ARROW)', 'value': 'CHECK - ABOARD'},
      {'action': 'POH / AFM', 'value': 'CHECK - IN AIRCRAFT'},
      {'action': 'Weight & Balance', 'value': 'CHECK - WITHIN LIMITS'},
      {'type': 'header', 'text': 'FUEL & OIL'},
      {'action': 'Fuel Quantity', 'value': 'CHECK - ALL TANKS', 'critical': true},
      {'action': 'Fuel Caps', 'value': 'SECURE', 'critical': true},
      {'action': 'Fuel Sumps', 'value': 'DRAIN & CHECK - CLEAR'},
      {'action': 'Oil Level', 'value': 'CHECK PER POH', 'critical': true},
      {'type': 'header', 'text': 'EXTERIOR INSPECTION'},
      {'action': 'Pitot Cover', 'value': 'REMOVE', 'critical': true},
      {'action': 'Pitot / Static Ports', 'value': 'CLEAR'},
      {'action': 'Control Surfaces', 'value': 'FREE & CORRECT'},
      {'action': 'Tires & Brakes', 'value': 'CHECK'},
      {'action': 'Lights', 'value': 'CHECK - OPERATIONAL'},
      {'action': 'Tie-Downs / Chocks', 'value': 'REMOVE'},
    ],
    'Before Start': [
      {'action': 'Seats & Seat Belts', 'value': 'ADJUST & SECURE'},
      {'action': 'Brakes', 'value': 'TEST & SET'},
      {'action': 'Circuit Breakers', 'value': 'CHECK - IN'},
      {'action': 'Fuel Selector', 'value': 'SET PER POH', 'critical': true},
      {'action': 'Mixture', 'value': 'RICH'},
      {'action': 'Avionics Master', 'value': 'OFF'},
    ],
    'Engine Start': [
      {'action': 'Throttle', 'value': 'SET PER POH'},
      {'action': 'Mixture', 'value': 'RICH', 'critical': true},
      {'action': 'Master Switch', 'value': 'ON'},
      {'action': 'Beacon', 'value': 'ON'},
      {'action': 'Area', 'value': 'CLEAR - ANNOUNCE "CLEAR PROP"', 'critical': true},
      {'action': 'Ignition', 'value': 'START'},
      {'action': 'Oil Pressure', 'value': 'CHECK - GREEN ARC', 'critical': true},
      {'action': 'Avionics Master', 'value': 'ON'},
    ],
    'Before Taxi': [
      {'action': 'Avionics', 'value': 'ON & SET'},
      {'action': 'Flight Instruments', 'value': 'CHECK - NO FLAGS'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Flaps', 'value': 'UP'},
      {'action': 'ATIS / Clearance', 'value': 'OBTAIN'},
      {'action': 'Brakes', 'value': 'CHECK ON ROLL', 'critical': true},
    ],
    'Run-Up': [
      {'action': 'Brakes', 'value': 'HOLD', 'critical': true},
      {'action': 'Throttle', 'value': 'RUN-UP RPM PER POH'},
      {'action': 'Magnetos', 'value': 'CHECK - DROP PER POH', 'critical': true},
      {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
      {'action': 'Ammeter / Alternator', 'value': 'CHECK'},
      {'action': 'Throttle', 'value': 'IDLE'},
    ],
    'Before Takeoff': [
      {'action': 'Fuel Selector', 'value': 'SET PER POH', 'critical': true},
      {'action': 'Mixture', 'value': 'SET FOR TAKEOFF', 'critical': true},
      {'action': 'Flaps', 'value': 'SET PER POH'},
      {'action': 'Trim', 'value': 'SET FOR TAKEOFF'},
      {'action': 'Doors & Windows', 'value': 'CLOSED & LATCHED'},
      {'action': 'Seat Belts', 'value': 'FASTENED', 'critical': true},
      {'action': 'Transponder', 'value': 'ALT'},
      {'action': 'Runways & Taxiways', 'value': 'CLEAR', 'critical': true},
    ],
    'Cruise': [
      {'action': 'Power', 'value': 'SET PER POH'},
      {'action': 'Mixture', 'value': 'LEAN AS REQUIRED'},
      {'action': 'Engine Instruments', 'value': 'GREEN ARC'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Fuel Remaining', 'value': 'CHECK - ADEQUATE RESERVE'},
    ],
    'Descent': [
      {'action': 'ATIS/AWOS', 'value': 'OBTAIN - DESTINATION'},
      {'action': 'Altimeter', 'value': 'SET - CURRENT BARO'},
      {'action': 'Mixture', 'value': 'RICHEN AS REQUIRED'},
      {'action': 'Seat Belts', 'value': 'FASTEN'},
    ],
    'Landing': [
      {'action': 'Fuel Selector', 'value': 'SET PER POH', 'critical': true},
      {'action': 'Mixture', 'value': 'RICH', 'critical': true},
      {'action': 'Flaps', 'value': 'SET PER POH'},
      {'action': 'Airspeed', 'value': 'VREF PER POH'},
      {'action': 'Runway', 'value': 'CLEAR', 'critical': true},
    ],
    'Shutdown': [
      {'action': 'Throttle', 'value': 'IDLE - COOL DOWN'},
      {'action': 'Avionics', 'value': 'OFF'},
      {'action': 'Mixture', 'value': 'IDLE CUTOFF', 'critical': true},
      {'action': 'Ignition', 'value': 'OFF - ENGINE STOPPED'},
      {'action': 'Master Switch', 'value': 'OFF'},
      {'action': 'Fuel Selector', 'value': 'OFF / AS REQUIRED'},
      {'action': 'Tie-Downs', 'value': 'SECURE'},
    ],
  };
}
