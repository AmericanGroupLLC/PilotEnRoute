/// Search, filters, month grouping and window totals for the logbook.
/// Pure Dart.
library;

import '../legality/calendar.dart';
import 'logbook_entry.dart';

class LogbookQuery {
  /// Matches airport (from/to/route), tail, type and remarks, case-insensitive.
  final String text;
  final DateTime? from;
  final DateTime? to;

  /// Empty = any.
  final String categoryClass;
  final bool night;
  final bool ifr;
  final bool flightReview;
  final bool ipc;

  const LogbookQuery({
    this.text = '',
    this.from,
    this.to,
    this.categoryClass = '',
    this.night = false,
    this.ifr = false,
    this.flightReview = false,
    this.ipc = false,
  });

  static const all = LogbookQuery();

  bool get isActive =>
      text.trim().isNotEmpty ||
      from != null ||
      to != null ||
      categoryClass.isNotEmpty ||
      night ||
      ifr ||
      flightReview ||
      ipc;

  int get filterCount => [
        from != null || to != null,
        categoryClass.isNotEmpty,
        night,
        ifr,
        flightReview,
        ipc,
      ].where((b) => b).length;

  LogbookQuery copyWith({
    String? text,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? categoryClass,
    bool? night,
    bool? ifr,
    bool? flightReview,
    bool? ipc,
  }) =>
      LogbookQuery(
        text: text ?? this.text,
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        categoryClass: categoryClass ?? this.categoryClass,
        night: night ?? this.night,
        ifr: ifr ?? this.ifr,
        flightReview: flightReview ?? this.flightReview,
        ipc: ipc ?? this.ipc,
      );

  bool matches(LogbookEntry e) {
    final q = text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        e.from,
        e.to,
        e.route,
        e.tailNumber,
        e.aircraftType,
        e.remarks,
      ].join(' ').toLowerCase();
      for (final word in q.split(RegExp(r'\s+'))) {
        if (!hay.contains(word)) return false;
      }
    }
    if (from != null && e.day.isBefore(dateOnly(from!))) return false;
    if (to != null && e.day.isAfter(dateOnly(to!))) return false;
    if (categoryClass.isNotEmpty &&
        !CategoryClass.same(e.categoryClass, categoryClass)) {
      return false;
    }
    if (night && !e.isNight) return false;
    if (ifr && !e.isIfr) return false;
    if (flightReview && !e.flightReview) return false;
    if (ipc && !e.ipc) return false;
    return true;
  }
}

/// Entries matching [q], newest first.
List<LogbookEntry> filterEntries(List<LogbookEntry> entries, LogbookQuery q) =>
    entries.where(q.matches).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

class MonthGroup {
  final DateTime month; // first day of the month
  final List<LogbookEntry> entries;
  const MonthGroup(this.month, this.entries);

  double get hours => entries.fold(0.0, (s, e) => s + e.totalTime);
}

/// Groups newest-first entries by calendar month, newest month first.
List<MonthGroup> groupByMonth(List<LogbookEntry> newestFirst) {
  final groups = <MonthGroup>[];
  for (final e in newestFirst) {
    final m = DateTime(e.date.year, e.date.month);
    if (groups.isEmpty || groups.last.month != m) {
      groups.add(MonthGroup(m, [e]));
    } else {
      groups.last.entries.add(e);
    }
  }
  return groups;
}

class LogbookTotals {
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
  final int nightTakeoffs;
  final int nightLandings;
  final int approaches;
  final int totalFlights;

  const LogbookTotals({
    this.totalTime = 0,
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
    this.nightTakeoffs = 0,
    this.nightLandings = 0,
    this.approaches = 0,
    this.totalFlights = 0,
  });

  factory LogbookTotals.of(Iterable<LogbookEntry> entries) {
    double total = 0, pic = 0, sic = 0, dual = 0, solo = 0, cfi = 0;
    double xc = 0, night = 0, act = 0, sim = 0;
    int dto = 0, dl = 0, nto = 0, nl = 0, app = 0, n = 0;
    for (final e in entries) {
      total += e.totalTime;
      pic += e.picTime;
      sic += e.sicTime;
      dual += e.dualReceived;
      solo += e.soloTime;
      cfi += e.cfiGiven;
      xc += e.crossCountry;
      night += e.night;
      act += e.actualInstrument;
      sim += e.simulatedInstrument;
      dto += e.dayTakeoffs;
      dl += e.dayLandings;
      nto += e.nightTakeoffs;
      nl += e.nightLandings;
      app += e.approaches;
      n++;
    }
    return LogbookTotals(
      totalTime: total,
      picTime: pic,
      sicTime: sic,
      dualReceived: dual,
      soloTime: solo,
      cfiGiven: cfi,
      crossCountry: xc,
      night: night,
      actualInstrument: act,
      simulatedInstrument: sim,
      dayTakeoffs: dto,
      dayLandings: dl,
      nightTakeoffs: nto,
      nightLandings: nl,
      approaches: app,
      totalFlights: n,
    );
  }
}

/// Totals for flights in the last [days] days up to and including [now]
/// (a flight exactly [days] - 1 days ago is in; [days] days ago is out, so
/// "30 days" is today plus the 29 before it). Null [days] = all time.
LogbookTotals totalsWithin(List<LogbookEntry> entries,
    {required DateTime now, int? days}) {
  if (days == null) return LogbookTotals.of(entries);
  final today = dateOnly(now);
  return LogbookTotals.of(entries.where((e) {
    final age = daysBetween(e.day, today);
    return age >= 0 && age < days;
  }));
}
