import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class LogbookEntry {
  final int? id;
  final DateTime date;
  final String aircraftType;
  final String tailNumber;
  final String from;
  final String to;
  final double totalTime;
  final double picTime;
  final double sicTime;
  final double dualReceived;
  final double cfiGiven;
  final double crossCountry;
  final double night;
  final double actualInstrument;
  final double simulatedInstrument;
  final int dayTakeoffs;
  final int dayLandings;
  final int nightTakeoffs;
  final int nightLandings;
  final int approaches;
  final String remarks;
  final String conditions;

  LogbookEntry({
    this.id,
    required this.date,
    required this.aircraftType,
    required this.tailNumber,
    required this.from,
    required this.to,
    required this.totalTime,
    this.picTime = 0,
    this.sicTime = 0,
    this.dualReceived = 0,
    this.cfiGiven = 0,
    this.crossCountry = 0,
    this.night = 0,
    this.actualInstrument = 0,
    this.simulatedInstrument = 0,
    this.dayTakeoffs = 0,
    this.dayLandings = 0,
    this.nightTakeoffs = 0,
    this.nightLandings = 0,
    this.approaches = 0,
    this.remarks = '',
    this.conditions = 'VMC',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'aircraft_type': aircraftType,
        'tail_number': tailNumber,
        'from_airport': from,
        'to_airport': to,
        'total_time': totalTime,
        'pic_time': picTime,
        'sic_time': sicTime,
        'dual_received': dualReceived,
        'cfi_given': cfiGiven,
        'cross_country': crossCountry,
        'night': night,
        'actual_instrument': actualInstrument,
        'simulated_instrument': simulatedInstrument,
        'day_takeoffs': dayTakeoffs,
        'day_landings': dayLandings,
        'night_takeoffs': nightTakeoffs,
        'night_landings': nightLandings,
        'approaches': approaches,
        'remarks': remarks,
        'conditions': conditions,
      };

  factory LogbookEntry.fromMap(Map<String, dynamic> map) => LogbookEntry(
        id: map['id'],
        date: DateTime.parse(map['date']),
        aircraftType: map['aircraft_type'] ?? '',
        tailNumber: map['tail_number'] ?? '',
        from: map['from_airport'] ?? '',
        to: map['to_airport'] ?? '',
        totalTime: (map['total_time'] ?? 0).toDouble(),
        picTime: (map['pic_time'] ?? 0).toDouble(),
        sicTime: (map['sic_time'] ?? 0).toDouble(),
        dualReceived: (map['dual_received'] ?? 0).toDouble(),
        cfiGiven: (map['cfi_given'] ?? 0).toDouble(),
        crossCountry: (map['cross_country'] ?? 0).toDouble(),
        night: (map['night'] ?? 0).toDouble(),
        actualInstrument: (map['actual_instrument'] ?? 0).toDouble(),
        simulatedInstrument: (map['simulated_instrument'] ?? 0).toDouble(),
        dayTakeoffs: map['day_takeoffs'] ?? 0,
        dayLandings: map['day_landings'] ?? 0,
        nightTakeoffs: map['night_takeoffs'] ?? 0,
        nightLandings: map['night_landings'] ?? 0,
        approaches: map['approaches'] ?? 0,
        remarks: map['remarks'] ?? '',
        conditions: map['conditions'] ?? 'VMC',
      );
}

class LogbookTotals {
  final double totalTime;
  final double picTime;
  final double sicTime;
  final double dualReceived;
  final double cfiGiven;
  final double crossCountry;
  final double night;
  final double actualInstrument;
  final double simulatedInstrument;
  final int dayTakeoffs;
  final int dayLandings;
  final int nightTakeoffs;
  final int nightLandings;
  final int approaches;
  final int totalFlights;

  LogbookTotals({
    this.totalTime = 0,
    this.picTime = 0,
    this.sicTime = 0,
    this.dualReceived = 0,
    this.cfiGiven = 0,
    this.crossCountry = 0,
    this.night = 0,
    this.actualInstrument = 0,
    this.simulatedInstrument = 0,
    this.dayTakeoffs = 0,
    this.dayLandings = 0,
    this.nightTakeoffs = 0,
    this.nightLandings = 0,
    this.approaches = 0,
    this.totalFlights = 0,
  });
}

class LogbookService extends ChangeNotifier {
  Database? _db;
  List<LogbookEntry> _entries = [];
  LogbookTotals _totals = LogbookTotals();
  bool _isLoading = false;

  List<LogbookEntry> get entries => _entries;
  LogbookTotals get totals => _totals;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    if (kIsWeb) {
      // Web: use in-memory demo data
      _entries = _getDemoEntries();
      _calculateTotals();
      notifyListeners();
      return;
    }
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'pilot_logbook.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logbook_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            aircraft_type TEXT,
            tail_number TEXT,
            from_airport TEXT,
            to_airport TEXT,
            total_time REAL DEFAULT 0,
            pic_time REAL DEFAULT 0,
            sic_time REAL DEFAULT 0,
            dual_received REAL DEFAULT 0,
            cfi_given REAL DEFAULT 0,
            cross_country REAL DEFAULT 0,
            night REAL DEFAULT 0,
            actual_instrument REAL DEFAULT 0,
            simulated_instrument REAL DEFAULT 0,
            day_takeoffs INTEGER DEFAULT 0,
            day_landings INTEGER DEFAULT 0,
            night_takeoffs INTEGER DEFAULT 0,
            night_landings INTEGER DEFAULT 0,
            approaches INTEGER DEFAULT 0,
            remarks TEXT DEFAULT '',
            conditions TEXT DEFAULT 'VMC'
          )
        ''');
      },
    );
    await loadEntries();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();
    if (_db != null) {
      final maps = await _db!.query('logbook_entries', orderBy: 'date DESC');
      _entries = maps.map((m) => LogbookEntry.fromMap(m)).toList();
    } else {
      _entries = _getDemoEntries();
    }
    _calculateTotals();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEntry(LogbookEntry entry) async {
    if (_db != null) {
      await _db!.insert('logbook_entries', entry.toMap());
      await loadEntries();
    } else {
      _entries.insert(0, LogbookEntry(
        id: _entries.length + 1,
        date: entry.date,
        aircraftType: entry.aircraftType,
        tailNumber: entry.tailNumber,
        from: entry.from,
        to: entry.to,
        totalTime: entry.totalTime,
        picTime: entry.picTime,
        dualReceived: entry.dualReceived,
        crossCountry: entry.crossCountry,
        night: entry.night,
        dayTakeoffs: entry.dayTakeoffs,
        dayLandings: entry.dayLandings,
        remarks: entry.remarks,
      ));
      _calculateTotals();
      notifyListeners();
    }
  }

  Future<void> deleteEntry(int id) async {
    if (_db != null) {
      await _db!.delete('logbook_entries', where: 'id = ?', whereArgs: [id]);
      await loadEntries();
    } else {
      _entries.removeWhere((e) => e.id == id);
      _calculateTotals();
      notifyListeners();
    }
  }

  void _calculateTotals() {
    double totalTime = 0, picTime = 0, sicTime = 0, dualReceived = 0;
    double cfiGiven = 0, crossCountry = 0, night = 0;
    double actualInstrument = 0, simulatedInstrument = 0;
    int dayTakeoffs = 0, dayLandings = 0, nightTakeoffs = 0, nightLandings = 0;
    int approaches = 0;

    for (final e in _entries) {
      totalTime += e.totalTime;
      picTime += e.picTime;
      sicTime += e.sicTime;
      dualReceived += e.dualReceived;
      cfiGiven += e.cfiGiven;
      crossCountry += e.crossCountry;
      night += e.night;
      actualInstrument += e.actualInstrument;
      simulatedInstrument += e.simulatedInstrument;
      dayTakeoffs += e.dayTakeoffs;
      dayLandings += e.dayLandings;
      nightTakeoffs += e.nightTakeoffs;
      nightLandings += e.nightLandings;
      approaches += e.approaches;
    }

    _totals = LogbookTotals(
      totalTime: totalTime,
      picTime: picTime,
      sicTime: sicTime,
      dualReceived: dualReceived,
      cfiGiven: cfiGiven,
      crossCountry: crossCountry,
      night: night,
      actualInstrument: actualInstrument,
      simulatedInstrument: simulatedInstrument,
      dayTakeoffs: dayTakeoffs,
      dayLandings: dayLandings,
      nightTakeoffs: nightTakeoffs,
      nightLandings: nightLandings,
      approaches: approaches,
      totalFlights: _entries.length,
    );
  }

  // Currency checks
  bool get isPassengerCurrent {
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    final recent = _entries.where((e) => e.date.isAfter(ninetyDaysAgo));
    final landings = recent.fold(0, (sum, e) => sum + e.dayLandings);
    return landings >= 3;
  }

  bool get isNightPassengerCurrent {
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    final recent = _entries.where((e) => e.date.isAfter(ninetyDaysAgo));
    final nightLandings = recent.fold(0, (sum, e) => sum + e.nightLandings);
    return nightLandings >= 3;
  }

  bool get isIfrCurrent {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    final recent = _entries.where((e) => e.date.isAfter(sixMonthsAgo));
    final approaches = recent.fold(0, (sum, e) => sum + e.approaches);
    return approaches >= 6;
  }

  List<LogbookEntry> _getDemoEntries() {
    return [
      LogbookEntry(
        id: 1,
        date: DateTime.now().subtract(const Duration(days: 5)),
        aircraftType: 'C172',
        tailNumber: 'N12345',
        from: 'KPAO',
        to: 'KSQL',
        totalTime: 1.2,
        picTime: 1.2,
        crossCountry: 1.2,
        dayTakeoffs: 1,
        dayLandings: 1,
        remarks: 'Night currency flight. Smooth conditions.',
      ),
      LogbookEntry(
        id: 2,
        date: DateTime.now().subtract(const Duration(days: 12)),
        aircraftType: 'C172',
        tailNumber: 'N12345',
        from: 'KPAO',
        to: 'KSJC',
        totalTime: 0.8,
        picTime: 0.8,
        dayTakeoffs: 3,
        dayLandings: 3,
        remarks: 'Pattern work, touch and goes.',
      ),
      LogbookEntry(
        id: 3,
        date: DateTime.now().subtract(const Duration(days: 20)),
        aircraftType: 'PA28',
        tailNumber: 'N67890',
        from: 'KPAO',
        to: 'KMRY',
        totalTime: 2.5,
        picTime: 2.5,
        crossCountry: 2.5,
        dayTakeoffs: 1,
        dayLandings: 1,
        remarks: 'Cross country to Monterey. Coastal VFR.',
      ),
      LogbookEntry(
        id: 4,
        date: DateTime.now().subtract(const Duration(days: 35)),
        aircraftType: 'C172',
        tailNumber: 'N12345',
        from: 'KPAO',
        to: 'KPAO',
        totalTime: 1.5,
        dualReceived: 1.5,
        actualInstrument: 0.8,
        approaches: 3,
        remarks: 'IFR training with CFII. ILS 28L, VOR 30, RNAV 28R.',
      ),
    ];
  }
}
