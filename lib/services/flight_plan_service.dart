import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Waypoint {
  final String identifier;
  final String name;
  final double lat;
  final double lon;
  final String type; // airport, vor, fix, ndb
  final double? altitude;

  Waypoint({
    required this.identifier,
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    this.altitude,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'lat': lat,
        'lon': lon,
        'type': type,
        'altitude': altitude,
      };

  factory Waypoint.fromJson(Map<String, dynamic> j) => Waypoint(
        identifier: j['identifier'] ?? '',
        name: j['name'] ?? '',
        lat: (j['lat'] ?? 0).toDouble(),
        lon: (j['lon'] ?? 0).toDouble(),
        type: j['type'] ?? 'fix',
        altitude: j['altitude']?.toDouble(),
      );
}

class FlightPlan {
  final String id;
  final String name;
  final String departure;
  final String destination;
  final String? alternate;
  final List<Waypoint> waypoints;
  final String aircraftType;
  final String tailNumber;
  final int cruiseAltitude;
  final int cruiseSpeed;
  final String flightRules; // VFR, IFR, SVFR
  final DateTime? etd;
  final double? estimatedTime;
  final String? route;
  final String remarks;
  final DateTime createdAt;

  FlightPlan({
    required this.id,
    required this.name,
    required this.departure,
    required this.destination,
    this.alternate,
    this.waypoints = const [],
    this.aircraftType = 'C172',
    this.tailNumber = '',
    this.cruiseAltitude = 3500,
    this.cruiseSpeed = 120,
    this.flightRules = 'VFR',
    this.etd,
    this.estimatedTime,
    this.route,
    this.remarks = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'departure': departure,
        'destination': destination,
        'alternate': alternate,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'aircraftType': aircraftType,
        'tailNumber': tailNumber,
        'cruiseAltitude': cruiseAltitude,
        'cruiseSpeed': cruiseSpeed,
        'flightRules': flightRules,
        'etd': etd?.toIso8601String(),
        'estimatedTime': estimatedTime,
        'route': route,
        'remarks': remarks,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FlightPlan.fromJson(Map<String, dynamic> j) => FlightPlan(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        departure: j['departure'] ?? '',
        destination: j['destination'] ?? '',
        alternate: j['alternate'],
        waypoints: (j['waypoints'] as List<dynamic>? ?? [])
            .map((w) => Waypoint.fromJson(w))
            .toList(),
        aircraftType: j['aircraftType'] ?? 'C172',
        tailNumber: j['tailNumber'] ?? '',
        cruiseAltitude: j['cruiseAltitude'] ?? 3500,
        cruiseSpeed: j['cruiseSpeed'] ?? 120,
        flightRules: j['flightRules'] ?? 'VFR',
        etd: j['etd'] != null ? DateTime.parse(j['etd']) : null,
        estimatedTime: j['estimatedTime']?.toDouble(),
        route: j['route'],
        remarks: j['remarks'] ?? '',
        createdAt: DateTime.parse(j['createdAt'] ?? DateTime.now().toIso8601String()),
      );
}

class FlightPlanService extends ChangeNotifier {
  List<FlightPlan> _plans = [];
  bool _isLoading = false;

  List<FlightPlan> get plans => _plans;
  bool get isLoading => _isLoading;

  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('flight_plans') ?? [];
      _plans = saved
          .map((s) => FlightPlan.fromJson(jsonDecode(s)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _plans = _getDemoPlans();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> savePlan(FlightPlan plan) async {
    final existing = _plans.indexWhere((p) => p.id == plan.id);
    if (existing >= 0) {
      _plans[existing] = plan;
    } else {
      _plans.insert(0, plan);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'flight_plans',
      _plans.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  // Calculate distance between two airports using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 3440.065; // nautical miles
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = (dLat / 2) * (dLat / 2) +
        _toRad(lat1) * _toRad(lat2) * (dLon / 2) * (dLon / 2);
    final c = 2 * (a < 1 ? a : 1 - a); // simplified
    return R * c;
  }

  double _toRad(double deg) => deg * 3.14159265358979 / 180;

  // Estimate flight time based on distance and speed
  double estimateFlightTime(double distanceNm, int speedKts) {
    if (speedKts <= 0) return 0;
    return distanceNm / speedKts;
  }

  // Generate FAA flight plan string
  String generateFaaFlightPlanString(FlightPlan plan) {
    final etdStr = plan.etd != null
        ? '${plan.etd!.hour.toString().padLeft(2, '0')}${plan.etd!.minute.toString().padLeft(2, '0')}'
        : '0000';
    final eteStr = plan.estimatedTime != null
        ? '${plan.estimatedTime!.floor().toString().padLeft(2, '0')}${((plan.estimatedTime! % 1) * 60).round().toString().padLeft(2, '0')}'
        : '0000';

    return '''
FAA FLIGHT PLAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TYPE: ${plan.flightRules}
AIRCRAFT: ${plan.aircraftType} / ${plan.tailNumber}
DEPARTURE: ${plan.departure}
DESTINATION: ${plan.destination}
ALTERNATE: ${plan.alternate ?? 'NONE'}
CRUISE ALT: ${plan.cruiseAltitude} ft MSL
TAS: ${plan.cruiseSpeed} kts
ETD: ${etdStr}Z
ETE: ${eteStr}
ROUTE: ${plan.route ?? plan.waypoints.map((w) => w.identifier).join(' ')}
REMARKS: ${plan.remarks}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File via 1800wxbrief.com or call 1-800-WX-BRIEF
''';
  }

  List<FlightPlan> _getDemoPlans() {
    return [
      FlightPlan(
        id: 'demo_001',
        name: 'Palo Alto → Monterey',
        departure: 'KPAO',
        destination: 'KMRY',
        alternate: 'KSNS',
        aircraftType: 'C172',
        tailNumber: 'N12345',
        cruiseAltitude: 4500,
        cruiseSpeed: 110,
        flightRules: 'VFR',
        estimatedTime: 1.8,
        route: 'KPAO V25 SALINAS KMRY',
        remarks: 'Coastal VFR. Request flight following.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      FlightPlan(
        id: 'demo_002',
        name: 'San Jose → Los Angeles',
        departure: 'KSJC',
        destination: 'KLAX',
        alternate: 'KBUR',
        aircraftType: 'C172',
        tailNumber: 'N12345',
        cruiseAltitude: 8500,
        cruiseSpeed: 115,
        flightRules: 'VFR',
        estimatedTime: 3.2,
        route: 'KSJC LOSHN V25 GORMAN KLAX',
        remarks: 'Bravo transition required. File IFR recommended.',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }
}
