/// Plain, locale-independent date text for the legality and minimums lines.
/// Pure Dart so the wording can be asserted in host tests.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "31 Oct 2028".
String dayMonthYear(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "2 Oct" when [d] is in the same year as [reference], else "2 Oct 2027".
String dayMonth(DateTime d, {required DateTime reference}) =>
    d.year == reference.year
        ? '${d.day} ${_months[d.month - 1]}'
        : dayMonthYear(d);

/// "Oct 2026" — used for logbook month headers.
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "2026-10-14".
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// "13:52Z" for a UTC instant.
String zuluTime(DateTime utc) {
  final u = utc.toUtc();
  return '${u.hour.toString().padLeft(2, '0')}:'
      '${u.minute.toString().padLeft(2, '0')}Z';
}
