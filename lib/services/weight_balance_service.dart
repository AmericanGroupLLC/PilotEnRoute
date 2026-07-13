import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weight & Balance service.
///
/// IMPORTANT: All built-in aircraft numbers below are REPRESENTATIVE / typical
/// values only. They are NOT a substitute for the actual weight & balance data
/// for a specific tail number. Empty weight, empty arm, station arms and CG
/// envelope limits vary by serial number, installed equipment and previous
/// modifications. ALWAYS verify against your aircraft's POH/AFM and the current
/// weight & balance record before flight.

const double kFuelWeightPerGallon = 6.0; // 100LL avgas, lb/gal (representative)

/// A single loading station (seat row, baggage area or a fuel tank).
class WBStation {
  final String name;
  final double arm; // inches aft of datum
  final bool isFuel; // if true, input is gallons and converted to weight
  final double? maxGallons; // fuel capacity (usable) when isFuel
  final double? maxWeight; // optional structural limit for baggage/seats

  const WBStation({
    required this.name,
    required this.arm,
    this.isFuel = false,
    this.maxGallons,
    this.maxWeight,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'arm': arm,
        'isFuel': isFuel,
        'maxGallons': maxGallons,
        'maxWeight': maxWeight,
      };

  factory WBStation.fromJson(Map<String, dynamic> j) => WBStation(
        name: j['name'] as String? ?? 'Station',
        arm: (j['arm'] as num?)?.toDouble() ?? 0,
        isFuel: j['isFuel'] as bool? ?? false,
        maxGallons: (j['maxGallons'] as num?)?.toDouble(),
        maxWeight: (j['maxWeight'] as num?)?.toDouble(),
      );
}

/// One point on the CG envelope: at [weight] lb the CG must be between
/// [fwdCG] and [aftCG] (inches aft of datum).
class WBEnvelopePoint {
  final double weight;
  final double fwdCG;
  final double aftCG;

  const WBEnvelopePoint(this.weight, this.fwdCG, this.aftCG);

  Map<String, dynamic> toJson() =>
      {'weight': weight, 'fwdCG': fwdCG, 'aftCG': aftCG};

  factory WBEnvelopePoint.fromJson(Map<String, dynamic> j) => WBEnvelopePoint(
        (j['weight'] as num?)?.toDouble() ?? 0,
        (j['fwdCG'] as num?)?.toDouble() ?? 0,
        (j['aftCG'] as num?)?.toDouble() ?? 0,
      );
}

class AircraftProfile {
  final String id;
  final String name;
  final double emptyWeight; // lb
  final double emptyArm; // in
  final double maxGross; // lb
  final List<WBStation> stations;
  final List<WBEnvelopePoint> envelope; // sorted by weight ascending
  final bool isBuiltIn;

  const AircraftProfile({
    required this.id,
    required this.name,
    required this.emptyWeight,
    required this.emptyArm,
    required this.maxGross,
    required this.stations,
    required this.envelope,
    this.isBuiltIn = false,
  });

  double get emptyMoment => emptyWeight * emptyArm;

  AircraftProfile copyWith({
    String? name,
    double? emptyWeight,
    double? emptyArm,
    double? maxGross,
    List<WBStation>? stations,
    List<WBEnvelopePoint>? envelope,
  }) {
    return AircraftProfile(
      id: id,
      name: name ?? this.name,
      emptyWeight: emptyWeight ?? this.emptyWeight,
      emptyArm: emptyArm ?? this.emptyArm,
      maxGross: maxGross ?? this.maxGross,
      stations: stations ?? this.stations,
      envelope: envelope ?? this.envelope,
      isBuiltIn: isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emptyWeight': emptyWeight,
        'emptyArm': emptyArm,
        'maxGross': maxGross,
        'stations': stations.map((s) => s.toJson()).toList(),
        'envelope': envelope.map((e) => e.toJson()).toList(),
        'isBuiltIn': isBuiltIn,
      };

  factory AircraftProfile.fromJson(Map<String, dynamic> j) => AircraftProfile(
        id: j['id'] as String? ??
            'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: j['name'] as String? ?? 'Custom Aircraft',
        emptyWeight: (j['emptyWeight'] as num?)?.toDouble() ?? 0,
        emptyArm: (j['emptyArm'] as num?)?.toDouble() ?? 0,
        maxGross: (j['maxGross'] as num?)?.toDouble() ?? 0,
        stations: ((j['stations'] as List?) ?? [])
            .map((s) => WBStation.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        envelope: ((j['envelope'] as List?) ?? [])
            .map((e) =>
                WBEnvelopePoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isBuiltIn: j['isBuiltIn'] as bool? ?? false,
      );
}

/// Result of a weight & balance computation.
class WBResult {
  final double totalWeight;
  final double totalMoment;
  final double cg; // double.nan when totalWeight <= 0
  final bool hasCg;
  final bool weightOk;
  final bool cgOk;
  final double fwdLimit; // interpolated fwd CG limit at totalWeight
  final double aftLimit; // interpolated aft CG limit at totalWeight

  const WBResult({
    required this.totalWeight,
    required this.totalMoment,
    required this.cg,
    required this.hasCg,
    required this.weightOk,
    required this.cgOk,
    required this.fwdLimit,
    required this.aftLimit,
  });
}

class WeightBalanceService extends ChangeNotifier {
  static const _kCustomProfiles = 'wb_custom_profiles';
  static const _kActiveId = 'wb_active_id';
  static const _kLoadingPrefix = 'wb_loading_'; // + profileId

  final List<AircraftProfile> _builtIn = _defaultProfiles();
  List<AircraftProfile> _custom = [];
  String? _activeId;

  /// Current loading values keyed by station name.
  /// For fuel stations the value is GALLONS; otherwise it is WEIGHT (lb).
  Map<String, double> _loading = {};

  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<AircraftProfile> get profiles => [..._builtIn, ..._custom];

  Map<String, double> get loading => Map.unmodifiable(_loading);

  AircraftProfile get activeProfile {
    final all = profiles;
    return all.firstWhere(
      (p) => p.id == _activeId,
      orElse: () => all.first,
    );
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCustomProfiles);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _custom = list
            .map((e) =>
                AircraftProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      _activeId = prefs.getString(_kActiveId) ?? _builtIn.first.id;
      _loadLoadingFor(_activeId!, prefs);
    } catch (_) {
      // Never crash on corrupt prefs — fall back to defaults.
      _custom = [];
      _activeId = _builtIn.first.id;
      _loading = {};
    }
    _loaded = true;
    notifyListeners();
  }

  void _loadLoadingFor(String profileId, SharedPreferences prefs) {
    _loading = {};
    final raw = prefs.getString('$_kLoadingPrefix$profileId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map;
        map.forEach((k, v) {
          _loading[k.toString()] = (v as num).toDouble();
        });
      } catch (_) {
        _loading = {};
      }
    }
  }

  Future<void> setActiveProfile(String id) async {
    _activeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
    _loadLoadingFor(id, prefs);
    notifyListeners();
  }

  Future<void> setStationValue(String stationName, double value) async {
    _loading[stationName] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_kLoadingPrefix${activeProfile.id}', jsonEncode(_loading));
  }

  double stationValue(String stationName) => _loading[stationName] ?? 0;

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kCustomProfiles, jsonEncode(_custom.map((p) => p.toJson()).toList()));
  }

  Future<void> addOrUpdateCustom(AircraftProfile profile) async {
    final idx = _custom.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _custom[idx] = profile;
    } else {
      _custom.add(profile);
    }
    await _persistCustom();
    notifyListeners();
  }

  Future<void> deleteCustom(String id) async {
    _custom.removeWhere((p) => p.id == id);
    if (_activeId == id) {
      _activeId = _builtIn.first.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveId, _activeId!);
      _loadLoadingFor(_activeId!, prefs);
    }
    await _persistCustom();
    notifyListeners();
  }

  String newCustomId() => 'custom_${DateTime.now().millisecondsSinceEpoch}';

  // ── Computation ────────────────────────────────────────────────────────────

  WBResult compute(AircraftProfile p, Map<String, double> loading) {
    double weight = p.emptyWeight;
    double moment = p.emptyMoment;

    for (final s in p.stations) {
      final input = loading[s.name] ?? 0;
      final w = s.isFuel ? input * kFuelWeightPerGallon : input;
      weight += w;
      moment += w * s.arm;
    }

    final hasCg = weight > 0;
    final cg = hasCg ? moment / weight : double.nan;

    final limits = cgLimitsAt(p, weight);
    final fwd = limits[0];
    final aft = limits[1];

    final weightOk = weight <= p.maxGross && weight >= _minEnvelopeWeight(p);
    final cgOk = hasCg && cg >= fwd - 1e-9 && cg <= aft + 1e-9 && weightOk;

    return WBResult(
      totalWeight: weight,
      totalMoment: moment,
      cg: cg,
      hasCg: hasCg,
      weightOk: weightOk,
      cgOk: cgOk,
      fwdLimit: fwd,
      aftLimit: aft,
    );
  }

  double _minEnvelopeWeight(AircraftProfile p) {
    if (p.envelope.isEmpty) return 0;
    return p.envelope.first.weight;
  }

  /// Returns [fwdCG, aftCG] limits interpolated for [weight].
  List<double> cgLimitsAt(AircraftProfile p, double weight) {
    final env = p.envelope;
    if (env.isEmpty) return [double.negativeInfinity, double.infinity];
    if (weight <= env.first.weight) {
      return [env.first.fwdCG, env.first.aftCG];
    }
    if (weight >= env.last.weight) {
      return [env.last.fwdCG, env.last.aftCG];
    }
    for (int i = 0; i < env.length - 1; i++) {
      final a = env[i];
      final b = env[i + 1];
      if (weight >= a.weight && weight <= b.weight) {
        final t = (weight - a.weight) / (b.weight - a.weight);
        return [
          a.fwdCG + (b.fwdCG - a.fwdCG) * t,
          a.aftCG + (b.aftCG - a.aftCG) * t,
        ];
      }
    }
    return [env.last.fwdCG, env.last.aftCG];
  }

  // ── Performance (rough, clearly-labeled estimates) ───────────────────────────

  /// Density altitude (ft) from pressure altitude (ft) and OAT (°C).
  /// DA = PA + 120 * (OAT - ISA_temp), ISA_temp = 15 - 1.98*(PA/1000).
  static double densityAltitude(double pressureAlt, double oatC) {
    final isaTemp = 15.0 - 1.98 * (pressureAlt / 1000.0);
    return pressureAlt + 120.0 * (oatC - isaTemp);
  }

  /// Rough takeoff-distance multiplier vs. a sea-level standard-day roll.
  /// Rule of thumb: ~10% more ground roll per 1000 ft of density altitude.
  static double takeoffFactor(double densityAlt) {
    final da = math.max(0.0, densityAlt);
    return 1.0 + (da / 1000.0) * 0.10;
  }

  // ── Built-in REPRESENTATIVE profiles ─────────────────────────────────────────
  // WARNING: typical/representative values only — verify against the actual POH.
  static List<AircraftProfile> _defaultProfiles() {
    return [
      // Cessna 172S Skyhawk SP (Normal category) — representative.
      const AircraftProfile(
        id: 'builtin_c172s',
        name: 'Cessna 172S Skyhawk',
        emptyWeight: 1680,
        emptyArm: 40.0,
        maxGross: 2550,
        isBuiltIn: true,
        stations: [
          WBStation(name: 'Front seats (pilot + pax)', arm: 37.0),
          WBStation(name: 'Rear seats', arm: 73.0),
          WBStation(name: 'Baggage area 1', arm: 95.0, maxWeight: 120),
          WBStation(name: 'Baggage area 2', arm: 123.0, maxWeight: 50),
          WBStation(name: 'Fuel', arm: 48.0, isFuel: true, maxGallons: 53),
        ],
        envelope: [
          WBEnvelopePoint(1500, 35.0, 47.3),
          WBEnvelopePoint(1950, 35.0, 47.3),
          WBEnvelopePoint(2550, 41.0, 47.3),
        ],
      ),
      // Piper PA-28-181 Archer III (Normal category) — representative.
      const AircraftProfile(
        id: 'builtin_pa28_181',
        name: 'Piper PA-28-181 Archer',
        emptyWeight: 1640,
        emptyArm: 87.0,
        maxGross: 2550,
        isBuiltIn: true,
        stations: [
          WBStation(name: 'Front seats (pilot + pax)', arm: 80.5),
          WBStation(name: 'Rear seats', arm: 118.1),
          WBStation(name: 'Baggage', arm: 142.8, maxWeight: 200),
          WBStation(name: 'Fuel', arm: 95.0, isFuel: true, maxGallons: 48),
        ],
        envelope: [
          WBEnvelopePoint(1500, 82.0, 93.0),
          WBEnvelopePoint(2050, 82.0, 93.0),
          WBEnvelopePoint(2550, 88.6, 93.0),
        ],
      ),
      // Cirrus SR22 (Normal category) — representative.
      const AircraftProfile(
        id: 'builtin_sr22',
        name: 'Cirrus SR22',
        emptyWeight: 2350,
        emptyArm: 139.5,
        maxGross: 3400,
        isBuiltIn: true,
        stations: [
          WBStation(name: 'Front seats (pilot + pax)', arm: 143.5),
          WBStation(name: 'Rear seats', arm: 180.0),
          WBStation(name: 'Baggage', arm: 208.0, maxWeight: 130),
          WBStation(name: 'Fuel', arm: 153.75, isFuel: true, maxGallons: 92),
        ],
        envelope: [
          WBEnvelopePoint(2250, 137.9, 148.1),
          WBEnvelopePoint(3400, 140.7, 148.1),
        ],
      ),
    ];
  }
}
