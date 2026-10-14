/// Calendar arithmetic the way 14 CFR part 61 counts it.
///
/// Part 61 counts some periods in days ("the preceding 90 days") and others in
/// calendar months, which always end on the last day of a month: a flight
/// review on 13 Oct 2026 is good "since the beginning of the 24th calendar
/// month before the month" of the flight, i.e. through 31 Oct 2028. Every
/// function here works on dates only; the time of day is dropped first.
library;

/// [d] with the time of day removed (local calendar day).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The last day of the month [months] calendar months after the month of
/// [from]. `endOfMonthAfter(13 Oct 2026, 24)` is 31 Oct 2028;
/// `endOfMonthAfter(31 Jan 2027, 1)` is 28 Feb 2027.
DateTime endOfMonthAfter(DateTime from, int months) =>
    DateTime(from.year, from.month + months + 1, 0);

/// The first day of the month [months] calendar months after [from].
DateTime startOfMonthAfter(DateTime from, int months) =>
    DateTime(from.year, from.month + months, 1);

/// Whole days from [a] to [b] by calendar date (positive when b is later).
/// Uses UTC dates so a daylight-saving change can never shave off a day.
int daysBetween(DateTime a, DateTime b) {
  final x = DateTime.utc(a.year, a.month, a.day);
  final y = DateTime.utc(b.year, b.month, b.day);
  return y.difference(x).inDays;
}

/// [d] plus [days] calendar days, as a local date.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Months between the month of [a] and the month of [b] (b later = positive).
int monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + (b.month - a.month);
