/// One logged flight. Pure Dart: no Flutter import, so the legality engine,
/// the CSV export and the search code can all be tested on the host.
library;

/// Aircraft category and class as 14 CFR 61.57 compares them.
///
/// The four airplane classes a renter normally flies are offered as presets;
/// anything else is typed in and compared as text ("Glider", "Rotorcraft
/// helicopter"...). An empty value means the entry predates the v2 logbook
/// and was never given one, so it cannot count toward currency until edited.
class CategoryClass {
  const CategoryClass._();

  static const String asel = 'ASEL';
  static const String amel = 'AMEL';
  static const String ases = 'ASES';
  static const String ames = 'AMES';

  static const List<String> presets = [asel, amel, ases, ames];

  static String label(String code) => switch (code) {
        asel => 'Airplane single-engine land',
        amel => 'Airplane multi-engine land',
        ases => 'Airplane single-engine sea',
        ames => 'Airplane multi-engine sea',
        '' => 'Not set',
        _ => code,
      };

  /// Case- and space-insensitive comparison, so "asel " matches "ASEL".
  static bool same(String a, String b) {
    final x = a.trim().toUpperCase();
    final y = b.trim().toUpperCase();
    return x.isNotEmpty && x == y;
  }
}

class LogbookEntry {
  final int? id;
  final DateTime date;
  final String aircraftType;
  final String tailNumber;

  /// ASEL / AMEL / ASES / AMES or free text. Empty on rows migrated from v1.
  final String categoryClass;
  final bool tailwheel;

  final String from;
  final String to;
  final String route;

  final double totalTime;
  final double picTime;
  final double sicTime;
  final double dualReceived;
  final double soloTime;
  final double cfiGiven;
  final double crossCountry;
  final double night;
  final double actualInstrument;
  final double simulatedInstrument;

  final int dayTakeoffs;
  final int dayLandings;

  /// Of [dayLandings], how many were to a full stop. Only matters for a
  /// tailwheel airplane, where 61.57(a)(1)(ii) counts full stops only.
  final int dayFullStopLandings;
  final int nightTakeoffs;

  /// Night landings to a full stop, flown between 1 h after sunset and 1 h
  /// before sunrise. The pilot logs them as such; the engine does not
  /// reinterpret them.
  final int nightLandings;

  final int approaches;
  final bool holding;
  final bool tracking;

  final bool flightReview;
  final bool ipc;
  final bool practicalTest;

  /// 'VFR' or 'IFR'. Rows from v1 carry 'VMC', which reads as VFR.
  final String conditions;

  /// The pilot marked this as a night flight (e.g. from the Go Card toggle).
  final bool nightFlight;

  final String remarks;

  const LogbookEntry({
    this.id,
    required this.date,
    required this.aircraftType,
    required this.tailNumber,
    required this.from,
    required this.to,
    required this.totalTime,
    this.categoryClass = '',
    this.tailwheel = false,
    this.route = '',
    this.picTime = 0,
    this.sicTime = 0,
    this.dualReceived = 0,
    this.soloTime = 0,
    this.cfiGiven = 0,
    this.crossCountry = 0,
    this.night = 0,
    this.actualInstrument = 0,
    this.simulatedInstrument = 0,
    this.dayTakeoffs = 0,
    this.dayLandings = 0,
    this.dayFullStopLandings = 0,
    this.nightTakeoffs = 0,
    this.nightLandings = 0,
    this.approaches = 0,
    this.holding = false,
    this.tracking = false,
    this.flightReview = false,
    this.ipc = false,
    this.practicalTest = false,
    this.conditions = 'VFR',
    this.nightFlight = false,
    this.remarks = '',
  });

  /// Calendar day of the flight, with the time of day dropped.
  DateTime get day => DateTime(date.year, date.month, date.day);

  int get totalTakeoffs => dayTakeoffs + nightTakeoffs;
  int get totalLandings => dayLandings + nightLandings;

  /// Full-stop landings: the day ones the pilot marked as such, plus every
  /// night landing (which are logged as full stops by definition).
  int get fullStopLandings => dayFullStopLandings + nightLandings;

  bool get isIfr =>
      conditions.toUpperCase() == 'IFR' ||
      actualInstrument > 0 ||
      simulatedInstrument > 0 ||
      approaches > 0;

  bool get isNight =>
      nightFlight || night > 0 || nightTakeoffs > 0 || nightLandings > 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'aircraft_type': aircraftType,
        'tail_number': tailNumber,
        'category_class': categoryClass,
        'tailwheel': tailwheel ? 1 : 0,
        'from_airport': from,
        'to_airport': to,
        'route': route,
        'total_time': totalTime,
        'pic_time': picTime,
        'sic_time': sicTime,
        'dual_received': dualReceived,
        'solo_time': soloTime,
        'cfi_given': cfiGiven,
        'cross_country': crossCountry,
        'night': night,
        'actual_instrument': actualInstrument,
        'simulated_instrument': simulatedInstrument,
        'day_takeoffs': dayTakeoffs,
        'day_landings': dayLandings,
        'day_full_stop_landings': dayFullStopLandings,
        'night_takeoffs': nightTakeoffs,
        'night_landings': nightLandings,
        'approaches': approaches,
        'holding': holding ? 1 : 0,
        'tracking': tracking ? 1 : 0,
        'flight_review': flightReview ? 1 : 0,
        'ipc': ipc ? 1 : 0,
        'practical_test': practicalTest ? 1 : 0,
        'conditions': conditions,
        'night_flight': nightFlight ? 1 : 0,
        'remarks': remarks,
      };

  factory LogbookEntry.fromMap(Map<String, Object?> map) {
    double d(String k) => (map[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    bool b(String k) => i(k) != 0;
    String s(String k) => map[k]?.toString() ?? '';
    final cond = s('conditions');
    return LogbookEntry(
      id: (map['id'] as num?)?.toInt(),
      date: DateTime.parse(s('date')),
      aircraftType: s('aircraft_type'),
      tailNumber: s('tail_number'),
      categoryClass: s('category_class'),
      tailwheel: b('tailwheel'),
      from: s('from_airport'),
      to: s('to_airport'),
      route: s('route'),
      totalTime: d('total_time'),
      picTime: d('pic_time'),
      sicTime: d('sic_time'),
      dualReceived: d('dual_received'),
      soloTime: d('solo_time'),
      cfiGiven: d('cfi_given'),
      crossCountry: d('cross_country'),
      night: d('night'),
      actualInstrument: d('actual_instrument'),
      simulatedInstrument: d('simulated_instrument'),
      dayTakeoffs: i('day_takeoffs'),
      dayLandings: i('day_landings'),
      dayFullStopLandings: i('day_full_stop_landings'),
      nightTakeoffs: i('night_takeoffs'),
      nightLandings: i('night_landings'),
      approaches: i('approaches'),
      holding: b('holding'),
      tracking: b('tracking'),
      flightReview: b('flight_review'),
      ipc: b('ipc'),
      practicalTest: b('practical_test'),
      conditions: cond.isEmpty || cond == 'VMC' ? 'VFR' : cond,
      nightFlight: b('night_flight'),
      remarks: s('remarks'),
    );
  }

  LogbookEntry copyWith({
    int? id,
    bool clearId = false,
    DateTime? date,
    String? aircraftType,
    String? tailNumber,
    String? categoryClass,
    bool? tailwheel,
    String? from,
    String? to,
    String? route,
    double? totalTime,
    double? picTime,
    double? sicTime,
    double? dualReceived,
    double? soloTime,
    double? cfiGiven,
    double? crossCountry,
    double? night,
    double? actualInstrument,
    double? simulatedInstrument,
    int? dayTakeoffs,
    int? dayLandings,
    int? dayFullStopLandings,
    int? nightTakeoffs,
    int? nightLandings,
    int? approaches,
    bool? holding,
    bool? tracking,
    bool? flightReview,
    bool? ipc,
    bool? practicalTest,
    String? conditions,
    bool? nightFlight,
    String? remarks,
  }) {
    return LogbookEntry(
      id: clearId ? null : (id ?? this.id),
      date: date ?? this.date,
      aircraftType: aircraftType ?? this.aircraftType,
      tailNumber: tailNumber ?? this.tailNumber,
      categoryClass: categoryClass ?? this.categoryClass,
      tailwheel: tailwheel ?? this.tailwheel,
      from: from ?? this.from,
      to: to ?? this.to,
      route: route ?? this.route,
      totalTime: totalTime ?? this.totalTime,
      picTime: picTime ?? this.picTime,
      sicTime: sicTime ?? this.sicTime,
      dualReceived: dualReceived ?? this.dualReceived,
      soloTime: soloTime ?? this.soloTime,
      cfiGiven: cfiGiven ?? this.cfiGiven,
      crossCountry: crossCountry ?? this.crossCountry,
      night: night ?? this.night,
      actualInstrument: actualInstrument ?? this.actualInstrument,
      simulatedInstrument: simulatedInstrument ?? this.simulatedInstrument,
      dayTakeoffs: dayTakeoffs ?? this.dayTakeoffs,
      dayLandings: dayLandings ?? this.dayLandings,
      dayFullStopLandings: dayFullStopLandings ?? this.dayFullStopLandings,
      nightTakeoffs: nightTakeoffs ?? this.nightTakeoffs,
      nightLandings: nightLandings ?? this.nightLandings,
      approaches: approaches ?? this.approaches,
      holding: holding ?? this.holding,
      tracking: tracking ?? this.tracking,
      flightReview: flightReview ?? this.flightReview,
      ipc: ipc ?? this.ipc,
      practicalTest: practicalTest ?? this.practicalTest,
      conditions: conditions ?? this.conditions,
      nightFlight: nightFlight ?? this.nightFlight,
      remarks: remarks ?? this.remarks,
    );
  }
}
