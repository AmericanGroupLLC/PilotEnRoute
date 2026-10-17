/// "Copy as CSV": one column per logbook field, RFC 4180 quoting, and
/// "Paste CSV", which reads that same text back.
///
/// RFC 4180: records end in CRLF; a field containing a comma, a double quote,
/// CR or LF is enclosed in double quotes, and a double quote inside it is
/// written twice.
library;

import '../legality/date_text.dart';
import 'entry_validation.dart';
import 'logbook_entry.dart';

const List<String> csvHeader = [
  'Date',
  'Aircraft type',
  'Tail number',
  'Category/class',
  'Tailwheel',
  'From',
  'To',
  'Route',
  'Total',
  'PIC',
  'SIC',
  'Dual received',
  'Solo',
  'CFI given',
  'Cross-country',
  'Night',
  'Actual instrument',
  'Simulated instrument',
  'Day takeoffs',
  'Day landings',
  'Day full-stop landings',
  'Night takeoffs',
  'Night full-stop landings',
  'Approaches',
  'Holding',
  'Course tracking',
  'Flight review',
  'IPC',
  'Practical test',
  'Flight rules',
  'Night flight',
  'Remarks',
];

String csvField(String value) {
  final needsQuotes = value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// Tenths as "1.3"; anything finer in full ("1.25"), so Paste CSV gets back
/// exactly what was logged.
String _h(double v) {
  final tenths = v.toStringAsFixed(1);
  return double.parse(tenths) == v ? tenths : v.toString();
}
String _yn(bool b) => b ? 'Y' : '';

List<String> csvRow(LogbookEntry e) => [
      isoDate(e.date),
      e.aircraftType,
      e.tailNumber,
      e.categoryClass,
      _yn(e.tailwheel),
      e.from,
      e.to,
      e.route,
      _h(e.totalTime),
      _h(e.picTime),
      _h(e.sicTime),
      _h(e.dualReceived),
      _h(e.soloTime),
      _h(e.cfiGiven),
      _h(e.crossCountry),
      _h(e.night),
      _h(e.actualInstrument),
      _h(e.simulatedInstrument),
      '${e.dayTakeoffs}',
      '${e.dayLandings}',
      '${e.dayFullStopLandings}',
      '${e.nightTakeoffs}',
      '${e.nightLandings}',
      '${e.approaches}',
      _yn(e.holding),
      _yn(e.tracking),
      _yn(e.flightReview),
      _yn(e.ipc),
      _yn(e.practicalTest),
      e.conditions,
      _yn(e.nightFlight),
      e.remarks,
    ];

/// The whole logbook, oldest flight first, header included.
String logbookToCsv(List<LogbookEntry> entries) {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  final b = StringBuffer()
    ..write(csvHeader.map(csvField).join(','))
    ..write('\r\n');
  for (final e in sorted) {
    b
      ..write(csvRow(e).map(csvField).join(','))
      ..write('\r\n');
  }
  return b.toString();
}

/// Splits RFC 4180 text into records of fields. Accepts CRLF or LF record
/// ends and a final record with no line end; blank lines are skipped.
/// Throws [FormatException] on a quote that is never closed.
List<List<String>> parseCsvRecords(String text) =>
    _parseCsv(text).map((r) => r.$2).toList();

/// Records with the 1-based physical line each one starts on (a quoted
/// remark can span several lines).
List<(int, List<String>)> _parseCsv(String text) {
  final records = <(int, List<String>)>[];
  var line = 1;
  var recordLine = 1;
  var record = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false;
  var i = 0;
  if (text.startsWith('\uFEFF')) i = 1; // byte-order mark from spreadsheets

  void endField() {
    record.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRecord() {
    endField();
    if (!(record.length == 1 && record.first.isEmpty)) {
      records.add((recordLine, record));
    }
    record = <String>[];
    line++;
    recordLine = line;
  }

  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        if (c == '\n' || (c == '\r' && !(i + 1 < text.length && text[i + 1] == '\n'))) {
          line++;
        }
        field.write(c);
      }
      i++;
      continue;
    }
    if (c == '"' && !fieldStarted && field.isEmpty) {
      inQuotes = true;
      fieldStarted = true;
    } else if (c == ',') {
      endField();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      endRecord();
      i++;
    } else if (c == '\n' || c == '\r') {
      endRecord();
    } else {
      field.write(c);
      fieldStarted = true;
    }
    i++;
  }
  if (inQuotes) {
    throw const FormatException('A quoted field is never closed');
  }
  if (field.isNotEmpty || record.isNotEmpty) endRecord();
  return records;
}

class CsvImportError {
  /// 1-based physical line the record starts on in the pasted text (the
  /// header is line 1).
  final int line;
  final String message;
  const CsvImportError(this.line, this.message);

  @override
  String toString() => 'Line $line: $message';
}

class CsvImportResult {
  /// Rows that read cleanly and are not already in the logbook.
  final List<LogbookEntry> entries;

  /// Rows identical (as exported) to a flight already in the logbook, one
  /// row per existing copy.
  final int duplicates;

  final List<CsvImportError> errors;

  /// Set when the whole text is unusable (no header, wrong format).
  final String? fatal;

  const CsvImportResult({
    this.entries = const [],
    this.duplicates = 0,
    this.errors = const [],
    this.fatal,
  });
}

/// Reads text produced by "Copy as CSV" back into entries. Only this app's
/// own export is accepted: every [csvHeader] column must be present (in any
/// order). Other logbooks' layouts are not guessed.
CsvImportResult logbookFromCsv(String text,
    {List<LogbookEntry> existing = const []}) {
  final List<(int, List<String>)> records;
  try {
    records = _parseCsv(text);
  } on FormatException catch (e) {
    return CsvImportResult(fatal: 'Not readable as CSV: ${e.message}.');
  }
  if (records.isEmpty) {
    return const CsvImportResult(fatal: 'The clipboard is empty.');
  }
  final header = [for (final h in records.first.$2) h.trim()];
  final missing = [for (final h in csvHeader) if (!header.contains(h)) h];
  if (missing.isNotEmpty) {
    return CsvImportResult(
        fatal: 'This is not a PilotEnRoute logbook CSV. Missing column'
            '${missing.length == 1 ? '' : 's'}: ${missing.take(4).join(', ')}'
            '${missing.length > 4 ? '…' : ''}.');
  }
  final col = {for (final h in csvHeader) h: header.indexOf(h)};

  // How many copies of each flight the logbook already holds. A pasted row is
  // a duplicate only while copies remain, so two identical flights in one
  // export both import into an empty logbook.
  final remaining = <String, int>{};
  for (final e in existing) {
    final k = csvRow(e).join('\u0001');
    remaining[k] = (remaining[k] ?? 0) + 1;
  }
  final entries = <LogbookEntry>[];
  final errors = <CsvImportError>[];
  var duplicates = 0;

  for (var r = 1; r < records.length; r++) {
    final row = records[r].$2;
    final line = records[r].$1;
    if (row.length != header.length) {
      errors.add(CsvImportError(line,
          'Expected ${header.length} fields, found ${row.length}'));
      continue;
    }
    String v(String h) {
      final i = col[h]!;
      return i < row.length ? row[i].trim() : '';
    }

    final problems = <String>[];
    double hours(String h) {
      final p = parseHours(v(h));
      if (!p.ok) problems.add('$h: ${p.error}');
      return p.value ?? 0;
    }

    int count(String h) {
      final p = parseCount(v(h));
      if (!p.ok) problems.add('$h: ${p.error}');
      return p.value ?? 0;
    }

    bool flag(String h) {
      final s = v(h).toUpperCase();
      if (s.isEmpty || s == 'N' || s == 'NO' || s == 'FALSE' || s == '0') {
        return false;
      }
      if (s == 'Y' || s == 'YES' || s == 'TRUE' || s == '1') return true;
      problems.add('$h: expected Y or empty');
      return false;
    }

    final dateText = v('Date');
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dateText);
    DateTime? date;
    if (m != null) {
      final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
      final candidate = DateTime(y, mo, d);
      if (candidate.month == mo && candidate.day == d) date = candidate;
    }
    if (date == null) problems.add('Date: expected YYYY-MM-DD');

    final rules = v('Flight rules').toUpperCase();
    if (rules.isNotEmpty && rules != 'VFR' && rules != 'IFR') {
      problems.add('Flight rules: expected VFR or IFR');
    }

    final entry = LogbookEntry(
      date: date ?? DateTime(1970),
      aircraftType: v('Aircraft type'),
      tailNumber: v('Tail number'),
      categoryClass: v('Category/class'),
      tailwheel: flag('Tailwheel'),
      from: v('From'),
      to: v('To'),
      route: v('Route'),
      totalTime: hours('Total'),
      picTime: hours('PIC'),
      sicTime: hours('SIC'),
      dualReceived: hours('Dual received'),
      soloTime: hours('Solo'),
      cfiGiven: hours('CFI given'),
      crossCountry: hours('Cross-country'),
      night: hours('Night'),
      actualInstrument: hours('Actual instrument'),
      simulatedInstrument: hours('Simulated instrument'),
      dayTakeoffs: count('Day takeoffs'),
      dayLandings: count('Day landings'),
      dayFullStopLandings: count('Day full-stop landings'),
      nightTakeoffs: count('Night takeoffs'),
      nightLandings: count('Night full-stop landings'),
      approaches: count('Approaches'),
      holding: flag('Holding'),
      tracking: flag('Course tracking'),
      flightReview: flag('Flight review'),
      ipc: flag('IPC'),
      practicalTest: flag('Practical test'),
      conditions: rules.isEmpty ? 'VFR' : rules,
      nightFlight: flag('Night flight'),
      remarks: row[col['Remarks']!],
    );

    if (problems.isEmpty) {
      // Same checks as the entry form, except category/class: rows logged
      // before the v2 logbook were exported without one.
      final cross = crossCheck(entry)..remove('categoryClass');
      problems.addAll(cross.values);
    }
    if (problems.isNotEmpty) {
      errors.add(CsvImportError(line, problems.join('; ')));
      continue;
    }
    final key = csvRow(entry).join('\u0001');
    final left = remaining[key] ?? 0;
    if (left > 0) {
      remaining[key] = left - 1;
      duplicates++;
      continue;
    }
    entries.add(entry);
  }
  return CsvImportResult(
      entries: entries, duplicates: duplicates, errors: errors);
}
