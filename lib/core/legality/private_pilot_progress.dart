/// A student's progress toward the private pilot aeronautical experience of
/// 14 CFR 61.109(a) (airplane single-engine rating), worked out from the
/// student's own logbook entries.
///
/// Pure Dart and deterministic: the "preceding 2 calendar months" window comes
/// from the injected `now`, never from the system clock.
///
/// Regulation text fetched from the eCFR versioner API on 2026-10-17
/// (https://www.ecfr.gov/api/versioner/v1/full/2026-10-01/title-14.xml?part=61&section=61.109):
///
/// > (a) For an airplane single-engine rating. Except as provided in paragraph
/// > (k) of this section, a person who applies for a private pilot certificate
/// > with an airplane category and single-engine class rating must log at
/// > least 40 hours of flight time that includes at least 20 hours of flight
/// > training from an authorized instructor and 10 hours of solo flight
/// > training in the areas of operation listed in § 61.107(b)(1) of this part,
/// > and the training must include at least—
/// > (1) 3 hours of cross-country flight training in a single-engine airplane;
/// > (2) Except as provided in § 61.110 of this part, 3 hours of night flight
/// > training in a single-engine airplane that includes—
/// > (i) One cross-country flight of over 100 nautical miles total distance;
/// > and
/// > (ii) 10 takeoffs and 10 landings to a full stop (with each landing
/// > involving a flight in the traffic pattern) at an airport.
/// > (3) 3 hours of flight training in a single-engine airplane on the control
/// > and maneuvering of an airplane solely by reference to instruments, ...
/// > (4) 3 hours of flight training with an authorized instructor in a
/// > single-engine airplane in preparation for the practical test, which must
/// > have been performed within the preceding 2 calendar months from the month
/// > of the test; and
/// > (5) 10 hours of solo flight time in a single-engine airplane, consisting
/// > of at least—
/// > (i) 5 hours of solo cross-country time;
/// > (ii) One solo cross country flight of 150 nautical miles total distance,
/// > with full-stop landings at three points, and one segment of the flight
/// > consisting of a straight-line distance of more than 50 nautical miles
/// > between the takeoff and landing locations; and
/// > (iii) Three takeoffs and three landings to a full stop (with each landing
/// > involving a flight in the traffic pattern) at an airport with an
/// > operating control tower.
///
/// How entries are read (and the limits, which the screen states):
/// - "Single-engine airplane" means category/class ASEL or ASES. The 20 h of
///   instruction and 10 h of solo are "in the areas of operation listed in
///   § 61.107(b)(1)", the single-engine airplane areas, so they count those
///   entries only. Entries with no class (v1 rows) or another class count
///   toward the 40 h of flight time only.
/// - Flight training is the entry's dual-received time. Cross-country, night
///   and instrument time is credited as training only up to the dual time of
///   an entry with no solo time, and as solo only up to the solo time of an
///   entry with no dual time. An entry that logs both dual and solo cannot be
///   split, so its cross-country/night/instrument time is not credited to
///   either, and the screen says how many such entries there are.
/// - Night takeoffs and landings are credited to (2)(ii) from dual-only
///   entries. Every night landing is logged as a full stop.
/// - (4) is counted for a practical test in the current month: dual time from
///   the first day of the second calendar month before it.
/// - The logbook stores neither distances nor whether an airport is towered,
///   so (2)(i), (5)(ii) and (5)(iii) are listed as "not tracked".
/// - Not handled: the paragraph (k) and 61.110 exceptions, part 141, and
///   simulator/FTD credit.
library;

import 'calendar.dart';
import '../logbook/logbook_entry.dart';

enum ProgressUnit { hours, count }

class ProgressItem {
  final String cite;
  final String title;
  final ProgressUnit unit;

  /// What 61.109(a) asks for.
  final double required;

  /// What the logbook shows. Zero for an item that is not tracked.
  final double logged;

  /// False when the logbook cannot show this item at all.
  final bool tracked;

  const ProgressItem({
    required this.cite,
    required this.title,
    required this.unit,
    required this.required,
    required this.logged,
    this.tracked = true,
  });

  bool get met => tracked && logged >= required - 1e-9;

  /// Still needed, never negative.
  double get remaining =>
      tracked ? (required - logged).clamp(0, double.infinity).toDouble() : 0;

  /// "12.4 of 40 h" / "6 of 10" / "Not tracked".
  String get progressText {
    if (!tracked) return 'Not tracked';
    return unit == ProgressUnit.hours
        ? '${_h(logged)} of ${_h(required)} h'
        : '${logged.round()} of ${required.round()}';
  }

  /// 0..1 for a progress bar.
  double get fraction =>
      !tracked || required <= 0 ? 0 : (logged / required).clamp(0, 1).toDouble();

  static String _h(double v) => v.toStringAsFixed(1);
}

class PrivatePilotProgress {
  final List<ProgressItem> items;

  /// Entries that log both dual and solo time with cross-country, night or
  /// instrument time, which cannot be split between the two.
  final int mixedEntries;

  /// Entries with no category/class (they count toward totals only).
  final int unclassedEntries;

  const PrivatePilotProgress({
    required this.items,
    required this.mixedEntries,
    required this.unclassedEntries,
  });

  Iterable<ProgressItem> get tracked => items.where((i) => i.tracked);

  /// Every item the logbook can show is met. Never means "eligible": the
  /// untracked items and the instructor's endorsements still apply.
  bool get trackedItemsMet => tracked.every((i) => i.met);

  int get metCount => tracked.where((i) => i.met).length;
}

bool _singleEngineAirplane(LogbookEntry e) =>
    CategoryClass.same(e.categoryClass, CategoryClass.asel) ||
    CategoryClass.same(e.categoryClass, CategoryClass.ases);

double _min(double a, double b) => a < b ? a : b;

PrivatePilotProgress privatePilotProgress({
  required List<LogbookEntry> entries,
  required DateTime now,
}) {
  var total = 0.0, dual = 0.0, solo = 0.0;
  var dualXc = 0.0, dualNight = 0.0, dualInstrument = 0.0, testPrep = 0.0;
  var nightTakeoffs = 0, nightLandings = 0;
  var seSolo = 0.0, soloXc = 0.0;
  var mixed = 0, unclassed = 0;

  final testPrepFrom = startOfMonthAfter(now, -2);
  final today = dateOnly(now);

  for (final e in entries) {
    total += e.totalTime;
    if (e.categoryClass.trim().isEmpty) unclassed++;
    if (!_singleEngineAirplane(e)) continue;

    dual += e.dualReceived;
    solo += e.soloTime;
    seSolo += e.soloTime;
    final instrument = e.actualInstrument + e.simulatedInstrument;
    final hasSplitTime = e.crossCountry > 0 ||
        e.night > 0 ||
        instrument > 0 ||
        e.nightTakeoffs > 0 ||
        e.nightLandings > 0;
    final isDual = e.dualReceived > 0;
    final isSolo = e.soloTime > 0;

    if (isDual && isSolo) {
      if (hasSplitTime) mixed++;
    } else if (isDual) {
      dualXc += _min(e.dualReceived, e.crossCountry);
      dualNight += _min(e.dualReceived, e.night);
      dualInstrument += _min(e.dualReceived, instrument);
      nightTakeoffs += e.nightTakeoffs;
      nightLandings += e.nightLandings;
    } else if (isSolo) {
      soloXc += _min(e.soloTime, e.crossCountry);
    }

    final day = e.day;
    if (isDual && !day.isBefore(testPrepFrom) && !day.isAfter(today)) {
      testPrep += e.dualReceived;
    }
  }

  return PrivatePilotProgress(
    mixedEntries: mixed,
    unclassedEntries: unclassed,
    items: [
      ProgressItem(
          cite: '61.109(a)',
          title: 'Flight time',
          unit: ProgressUnit.hours,
          required: 40,
          logged: total),
      ProgressItem(
          cite: '61.109(a)',
          title: 'Flight training from an instructor (single-engine '
              'airplane)',
          unit: ProgressUnit.hours,
          required: 20,
          logged: dual),
      ProgressItem(
          cite: '61.109(a)',
          title: 'Solo flight training (single-engine airplane)',
          unit: ProgressUnit.hours,
          required: 10,
          logged: solo),
      ProgressItem(
          cite: '61.109(a)(1)',
          title: 'Cross-country flight training',
          unit: ProgressUnit.hours,
          required: 3,
          logged: dualXc),
      ProgressItem(
          cite: '61.109(a)(2)',
          title: 'Night flight training',
          unit: ProgressUnit.hours,
          required: 3,
          logged: dualNight),
      const ProgressItem(
          cite: '61.109(a)(2)(i)',
          title: 'Night cross-country over 100 NM total',
          unit: ProgressUnit.count,
          required: 1,
          logged: 0,
          tracked: false),
      ProgressItem(
          cite: '61.109(a)(2)(ii)',
          title: 'Night takeoffs (training)',
          unit: ProgressUnit.count,
          required: 10,
          logged: nightTakeoffs.toDouble()),
      ProgressItem(
          cite: '61.109(a)(2)(ii)',
          title: 'Night full-stop landings (training)',
          unit: ProgressUnit.count,
          required: 10,
          logged: nightLandings.toDouble()),
      ProgressItem(
          cite: '61.109(a)(3)',
          title: 'Flight training by reference to instruments',
          unit: ProgressUnit.hours,
          required: 3,
          logged: dualInstrument),
      ProgressItem(
          cite: '61.109(a)(4)',
          title: 'Practical test preparation (last 2 calendar months)',
          unit: ProgressUnit.hours,
          required: 3,
          logged: testPrep),
      ProgressItem(
          cite: '61.109(a)(5)',
          title: 'Solo flight time, single-engine airplane',
          unit: ProgressUnit.hours,
          required: 10,
          logged: seSolo),
      ProgressItem(
          cite: '61.109(a)(5)(i)',
          title: 'Solo cross-country',
          unit: ProgressUnit.hours,
          required: 5,
          logged: soloXc),
      const ProgressItem(
          cite: '61.109(a)(5)(ii)',
          title: 'Solo cross-country of 150 NM, three full-stop points, '
              'one leg over 50 NM',
          unit: ProgressUnit.count,
          required: 1,
          logged: 0,
          tracked: false),
      const ProgressItem(
          cite: '61.109(a)(5)(iii)',
          title: 'Three solo full-stop takeoffs and landings at a towered '
              'airport',
          unit: ProgressUnit.count,
          required: 3,
          logged: 0,
          tracked: false),
    ],
  );
}
