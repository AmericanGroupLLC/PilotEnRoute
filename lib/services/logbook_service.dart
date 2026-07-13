import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Generates a clean, FAA-style logbook PDF from all current entries.
  ///
  /// Includes a header (with the pilot's name from shared_preferences
  /// 'profile_name' when available), a paginated table of every flight, and a
  /// totals summary that matches the app's aggregated [totals]. Produces a
  /// valid PDF even when the logbook is empty.
  Future<Uint8List> buildLogbookPdf() async {
    // Pilot name from profile (best-effort; never throws).
    String pilotName = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      pilotName = (prefs.getString('profile_name') ?? '').trim();
    } catch (_) {
      pilotName = '';
    }

    final entries = List<LogbookEntry>.from(_entries);
    final t = _totals;
    final dateFmt = DateFormat('MM/dd/yyyy');
    final generatedFmt = DateFormat('MMM d, yyyy • HH:mm');

    String h(double v) => v.toStringAsFixed(1);
    int ldg(LogbookEntry e) => e.dayLandings + e.nightLandings;

    final doc = pw.Document();

    const headers = <String>[
      'Date',
      'Aircraft',
      'Tail',
      'From',
      'To',
      'Total',
      'PIC',
      'Dual',
      'XC',
      'Night',
      'Inst',
      'Ldg',
    ];

    final dataRows = entries
        .map((e) => <String>[
              dateFmt.format(e.date),
              e.aircraftType,
              e.tailNumber,
              e.from,
              e.to,
              h(e.totalTime),
              h(e.picTime),
              h(e.dualReceived),
              h(e.crossCountry),
              h(e.night),
              h(e.actualInstrument + e.simulatedInstrument),
              ldg(e).toString(),
            ])
        .toList();

    final totalsRow = <String>[
      'TOTALS',
      '',
      '',
      '',
      '',
      h(t.totalTime),
      h(t.picTime),
      h(t.dualReceived),
      h(t.crossCountry),
      h(t.night),
      h(t.actualInstrument + t.simulatedInstrument),
      (t.dayLandings + t.nightLandings).toString(),
    ];

    pw.Widget summaryRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                'Pilot Logbook${pilotName.isNotEmpty ? ' — $pilotName' : ''}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600),
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // Title block.
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PILOT LOGBOOK',
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                pilotName.isNotEmpty ? pilotName : 'Pilot In Command',
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated ${generatedFmt.format(DateTime.now())} · '
                '${t.totalFlights} flight${t.totalFlights == 1 ? '' : 's'} · '
                '${h(t.totalTime)} total hours',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 8),
            ],
          ),
          // Entries table (or empty-state note).
          if (dataRows.isEmpty)
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 40),
              child: pw.Text(
                'No logbook entries recorded yet.',
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey600),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: [...dataRows, totalsRow],
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 16,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight,
                11: pw.Alignment.centerRight,
              },
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          pw.SizedBox(height: 18),
          // Totals summary section.
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TOTALS SUMMARY',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(children: [
                        summaryRow('Total Time', '${h(t.totalTime)} hrs'),
                        summaryRow('PIC', '${h(t.picTime)} hrs'),
                        summaryRow('SIC', '${h(t.sicTime)} hrs'),
                        summaryRow(
                            'Dual Received', '${h(t.dualReceived)} hrs'),
                        summaryRow('CFI Given', '${h(t.cfiGiven)} hrs'),
                      ]),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(children: [
                        summaryRow(
                            'Cross Country', '${h(t.crossCountry)} hrs'),
                        summaryRow('Night', '${h(t.night)} hrs'),
                        summaryRow(
                            'Actual Instrument', '${h(t.actualInstrument)} hrs'),
                        summaryRow('Simulated Instrument',
                            '${h(t.simulatedInstrument)} hrs'),
                        summaryRow('Approaches', t.approaches.toString()),
                      ]),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(children: [
                        summaryRow('Total Flights', t.totalFlights.toString()),
                        summaryRow('Day Takeoffs', t.dayTakeoffs.toString()),
                        summaryRow('Day Landings', t.dayLandings.toString()),
                        summaryRow(
                            'Night Takeoffs', t.nightTakeoffs.toString()),
                        summaryRow(
                            'Night Landings', t.nightLandings.toString()),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'I certify that the entries in this logbook are true and correct.',
            style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );

    return doc.save();
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
