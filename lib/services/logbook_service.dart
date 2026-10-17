import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/logbook/logbook_csv.dart';
import '../core/logbook/logbook_entry.dart';
import '../core/logbook/logbook_query.dart';
import '../core/minimums/go_record.dart';
import '../data/logbook_store.dart';

export '../core/logbook/logbook_entry.dart';
export '../core/logbook/logbook_query.dart' show LogbookTotals;

/// The pilot's logbook and Go check history, on the device.
///
/// Opens SQLite (`pilot_logbook.db`, schema v2) on first [init]. Web and
/// widget tests pass a [MemoryLogbookStore]. A fresh install starts empty:
/// no sample flights are ever shown, totalled or exported.
class LogbookService extends ChangeNotifier {
  LogbookService({LogbookStore? store}) : _store = store;

  LogbookStore? _store;
  Future<void>? _opening;
  List<LogbookEntry> _entries = [];
  List<GoCheckRecord> _checks = [];
  LogbookTotals _totals = const LogbookTotals();
  bool _isLoading = false;
  bool _ready = false;
  String? _error;

  List<LogbookEntry> get entries => _entries;
  List<GoCheckRecord> get checks => _checks;
  LogbookTotals get totals => _totals;
  bool get isLoading => _isLoading;
  bool get ready => _ready;
  String? get error => _error;

  /// Safe to call more than once; later calls wait for the first.
  Future<void> init() => _opening ??= _open();

  Future<void> _open() async {
    if (_store == null) {
      if (kIsWeb) {
        _store = MemoryLogbookStore();
      } else {
        try {
          final dbPath = await getDatabasesPath();
          final db = await openLogbookDatabase(
              databaseFactory, join(dbPath, 'pilot_logbook.db'));
          _store = SqfliteLogbookStore(db);
        } catch (e) {
          // Without a database the logbook says so rather than pretending to
          // save into memory and losing everything on the next launch.
          _error = 'The logbook database could not be opened: $e';
          _store = MemoryLogbookStore();
        }
      }
    }
    await loadEntries();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();
    final store = _store;
    if (store != null) {
      _entries = await store.allEntries();
      _checks = await store.allChecks();
    }
    _totals = LogbookTotals.of(_entries);
    _isLoading = false;
    _ready = true;
    notifyListeners();
  }

  Future<LogbookStore> _ensure() async {
    await init();
    return _store!;
  }

  Future<int> addEntry(LogbookEntry entry) async {
    final store = await _ensure();
    final id = await store.insertEntry(entry.copyWith(clearId: true));
    await loadEntries();
    return id;
  }

  Future<void> updateEntry(LogbookEntry entry) async {
    final store = await _ensure();
    await store.updateEntry(entry);
    await loadEntries();
  }

  Future<void> deleteEntry(int id) async {
    final store = await _ensure();
    await store.deleteEntry(id);
    await loadEntries();
  }

  /// Adds the flights read by "Paste CSV", then reloads once. If an insert
  /// fails, the list is still reloaded (so it shows what was added) and the
  /// error is rethrown with the count added so far.
  Future<int> importEntries(List<LogbookEntry> entries) async {
    final store = await _ensure();
    var added = 0;
    try {
      for (final e in entries) {
        await store.insertEntry(e.copyWith(clearId: true));
        added++;
      }
    } catch (e) {
      await loadEntries();
      throw StateError('Stopped after $added of ${entries.length} flights: $e');
    }
    await loadEntries();
    return added;
  }

  /// Puts back an entry removed by a swipe (the Undo in the snackbar).
  Future<void> restoreEntry(LogbookEntry entry) => addEntry(entry);

  /// The most recent entry, for "Log again".
  LogbookEntry? get lastEntry => _entries.isEmpty ? null : _entries.first;

  Future<void> saveCheck(GoCheckRecord record) async {
    final store = await _ensure();
    await store.insertCheck(record);
    _checks = await store.allChecks();
    notifyListeners();
  }

  Future<void> deleteCheck(int id) async {
    final store = await _ensure();
    await store.deleteCheck(id);
    _checks = await store.allChecks();
    notifyListeners();
  }

  /// RFC 4180 CSV of every entry, for "Copy as CSV".
  String toCsv() => logbookToCsv(_entries);

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
    // ASCII only: the PDF is drawn with the built-in Helvetica, which has no
    // glyph for U+2022 and dropped the separator from the exported header.
    final generatedFmt = DateFormat('MMM d, yyyy - HH:mm');

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
}
