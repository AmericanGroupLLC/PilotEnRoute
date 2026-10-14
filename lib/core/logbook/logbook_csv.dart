/// "Copy as CSV": one column per logbook field, RFC 4180 quoting.
///
/// RFC 4180: records end in CRLF; a field containing a comma, a double quote,
/// CR or LF is enclosed in double quotes, and a double quote inside it is
/// written twice.
library;

import '../legality/date_text.dart';
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

String _h(double v) => v.toStringAsFixed(1);
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
