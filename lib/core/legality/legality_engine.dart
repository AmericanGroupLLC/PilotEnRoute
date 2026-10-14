/// Works out, from the pilot's own logbook and profile, whether they are legal
/// for one planned flight under 14 CFR part 61, and the date each item is
/// valid through.
///
/// Pure Dart (no Flutter import) and deterministic: every date comes from the
/// planned flight or the injected `now`, never from the system clock.
///
/// The regulation text quoted in the doc comments below was fetched from the
/// eCFR versioner API on 2026-10-14
/// (https://www.ecfr.gov/api/versioner/v1/full/2026-10-01/title-14.xml?part=61&section=61.57,
/// and the same for 61.56, 61.23 and 61.87).
///
/// What the engine does NOT check, and says so in the UI: type ratings,
/// endorsements other than the student solo one, simulator/FTD credit rules,
/// the part 119/135 exceptions in 61.57(e), and BasicMed's aircraft and
/// operating limits. The pilot remains responsible for those.
library;

import 'calendar.dart';
import 'date_text.dart';
import 'pilot_profile.dart';
import '../logbook/logbook_entry.dart';

/// The flight the pilot is about to make.
class PlannedFlight {
  final DateTime date;
  final String categoryClass;
  final bool tailwheel;
  final bool passengers;
  final bool night;
  final bool ifr;

  const PlannedFlight({
    required this.date,
    required this.categoryClass,
    this.tailwheel = false,
    this.passengers = false,
    this.night = false,
    this.ifr = false,
  });

  DateTime get day => dateOnly(date);
}

enum RuleId {
  dayPassengers,
  nightPassengers,
  ifr,
  flightReview,
  medical,
  studentSolo,
  studentPassengers,
}

enum RuleState {
  /// Meets the rule on the flight date.
  valid,

  /// Was met once, no longer is.
  lapsed,

  /// 61.57(c) lapsed, but still inside the six calendar months in which it
  /// can be regained without an IPC.
  grace,

  /// 61.57(d): more than six calendar months past the lapse, IPC required.
  ipcRequired,

  /// Nothing on record to decide either way.
  unknown,

  /// Does not apply to this pilot at all (e.g. flight review for a student
  /// with a current solo endorsement).
  exempt,
}

class RuleStatus {
  final RuleId id;
  final String title;
  final String cite;

  /// Short noun phrase for the one-line result: "night passenger currency".
  final String shortLabel;

  /// Whether this planned flight needs the rule to be met.
  final bool required;
  final RuleState state;

  /// Last day the rule is met (inclusive).
  final DateTime? validThrough;

  /// First day it is no longer met (validThrough + 1 day).
  DateTime? get lapsedOn =>
      validThrough == null ? null : addDays(validThrough!, 1);

  /// One line: "Valid through 31 Oct 2028" / "Lapsed on 2 Oct 2026".
  final String summary;

  /// What is missing, in the pilot's terms. Null when nothing is missing.
  final String? shortfall;

  /// Extra context (assumptions, entries that could not count).
  final List<String> notes;

  const RuleStatus({
    required this.id,
    required this.title,
    required this.cite,
    required this.shortLabel,
    required this.required,
    required this.state,
    required this.summary,
    this.validThrough,
    this.shortfall,
    this.notes = const [],
  });

  bool get isMet => state == RuleState.valid || state == RuleState.exempt;

  /// True when this rule stops the planned flight.
  bool get blocks => required && !isMet;
}

class LegalityReport {
  final PlannedFlight flight;
  final List<RuleStatus> rules;

  /// Whether the logbook had any entries at all.
  final bool hasEntries;

  const LegalityReport({
    required this.flight,
    required this.rules,
    required this.hasEntries,
  });

  bool get legal => rules.every((r) => !r.blocks);

  RuleStatus? get firstBlocking {
    for (final r in rules) {
      if (r.blocks) return r;
    }
    return null;
  }

  RuleStatus rule(RuleId id) => rules.firstWhere((r) => r.id == id);

  /// "Not legal: night passenger currency lapsed 2 Oct". Null when legal.
  String? get notLegalLine {
    final r = firstBlocking;
    if (r == null) return null;
    final when = r.lapsedOn == null
        ? null
        : dayMonth(r.lapsedOn!, reference: flight.date);
    switch (r.state) {
      case RuleState.lapsed:
      case RuleState.grace:
        return when == null
            ? 'Not legal: ${r.shortLabel} not met'
            : 'Not legal: ${r.shortLabel} lapsed $when';
      case RuleState.ipcRequired:
        return 'Not legal: ${r.shortLabel} needs an instrument proficiency '
            'check';
      case RuleState.unknown:
        return 'Not legal: ${r.shortLabel} not on record';
      case RuleState.valid:
      case RuleState.exempt:
        return null;
    }
  }
}

/// The 61.23(d) table. Returns the last day the medical is good for
/// [privilege], or null when that class of medical never covers it.
///
/// > "Then your medical certificate expires, for that operation, at the end of
/// > the last day of the ... month after the month of the date of
/// > examination shown on the medical certificate."
///
/// - (1)(i) first-class, under 40, ATP PIC: 12th month
/// - (1)(ii) first-class, 40 or older, ATP PIC: 6th month
/// - (1)(iii) first-class, any age, commercial: 12th month
/// - (1)(iv) first-class, under 40, private/recreational/student/CFI: 60th
/// - (1)(v) first-class, 40 or older, private/...: 24th month
/// - (2)(i) second-class, any age, commercial: 12th month
/// - (2)(ii) second-class, under 40, private/...: 60th month
/// - (2)(iii) second-class, 40 or older, private/...: 24th month
/// - (3)(i) third-class, under 40, private/...: 60th month
/// - (3)(ii) third-class, 40 or older, private/...: 24th month
DateTime? medicalValidThrough({
  required MedicalKind kind,
  required DateTime examDate,
  required bool age40OrOlder,
  required MedicalPrivilege privilege,
}) {
  int? months;
  switch (kind) {
    case MedicalKind.first:
      months = switch (privilege) {
        MedicalPrivilege.first => age40OrOlder ? 6 : 12,
        MedicalPrivilege.second => 12,
        MedicalPrivilege.third => age40OrOlder ? 24 : 60,
      };
    case MedicalKind.second:
      months = switch (privilege) {
        MedicalPrivilege.first => null,
        MedicalPrivilege.second => 12,
        MedicalPrivilege.third => age40OrOlder ? 24 : 60,
      };
    case MedicalKind.third:
      months = privilege == MedicalPrivilege.third
          ? (age40OrOlder ? 24 : 60)
          : null;
    case MedicalKind.none:
    case MedicalKind.basicMed:
      months = null;
  }
  return months == null ? null : endOfMonthAfter(examDate, months);
}

class LegalityEngine {
  const LegalityEngine();

  LegalityReport evaluate({
    required List<LogbookEntry> entries,
    required PilotProfile profile,
    required PlannedFlight flight,
  }) {
    final f = flight.day;
    // Entries after the flight date cannot count toward it.
    final usable = entries.where((e) => !e.day.isAfter(f)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final rules = <RuleStatus>[
      if (profile.studentPilot) _studentPassengers(flight),
      _dayPassengers(usable, flight),
      _nightPassengers(usable, flight),
      _ifr(usable, flight, profile),
      _flightReview(usable, flight, profile),
      _medical(flight, profile),
      if (profile.studentPilot) _studentSolo(flight, profile),
    ];
    return LegalityReport(
      flight: flight,
      rules: rules,
      hasEntries: entries.isNotEmpty,
    );
  }

  // ── 61.57(a) ───────────────────────────────────────────────────────────

  /// 61.57(a)(1): "no person may act as a pilot in command of an aircraft
  /// carrying persons ... unless that person has made at least three takeoffs
  /// and three landings within the preceding 90 days, and— ... (ii) The
  /// required takeoffs and landings were performed in an aircraft of the same
  /// category, class, and type (if a class or type rating is required), and,
  /// if the aircraft to be flown is an airplane with a tailwheel, the takeoffs
  /// and landings must have been made to a full stop in an airplane with a
  /// tailwheel."
  ///
  /// Night landings count: they are landings. "Within the preceding 90 days"
  /// is read as: a landing on day F-90 counts for a flight on day F, one on
  /// day F-91 does not.
  RuleStatus _dayPassengers(List<LogbookEntry> usable, PlannedFlight flight) {
    final cc = flight.categoryClass;
    final tw = flight.tailwheel;
    final matching = usable
        .where((e) => CategoryClass.same(e.categoryClass, cc))
        .where((e) => !tw || e.tailwheel)
        .toList();
    int landingsOf(LogbookEntry e) => tw ? e.fullStopLandings : e.totalLandings;

    final anchor = _anchorDate(
      matching,
      takeoffs: (e) => e.totalTakeoffs,
      landings: landingsOf,
    );
    final aircraft = _withArticle(
        '${tw ? 'tailwheel ' : ''}${cc.isEmpty ? 'aircraft with no category/class' : cc}');
    final landingWord = tw ? 'full-stop landings' : 'landings';
    return _ninetyDayRule(
      id: RuleId.dayPassengers,
      title: 'Passengers',
      cite: '14 CFR 61.57(a)',
      shortLabel: 'passenger currency',
      required: flight.passengers,
      flight: flight,
      anchor: anchor,
      window: matching,
      takeoffs: (e) => e.totalTakeoffs,
      landings: landingsOf,
      need: (t, l) => _needText(t, l, landingWord,
          'in $aircraft before carrying passengers'),
      notes: _unclassifiedNote(usable, flight),
    );
  }

  // ── 61.57(b) ───────────────────────────────────────────────────────────

  /// 61.57(b)(1): "no person may act as pilot in command of an aircraft
  /// carrying persons during the period beginning 1 hour after sunset and
  /// ending 1 hour before sunrise, unless within the preceding 90 days that
  /// person has made at least three takeoffs and three landings to a full stop
  /// during the period beginning 1 hour after sunset and ending 1 hour before
  /// sunrise, and— ... (ii) The required takeoffs and landings were performed
  /// in an aircraft of the same category, class, and type (if a class or type
  /// rating is required)."
  RuleStatus _nightPassengers(List<LogbookEntry> usable, PlannedFlight flight) {
    final cc = flight.categoryClass;
    final matching =
        usable.where((e) => CategoryClass.same(e.categoryClass, cc)).toList();
    final anchor = _anchorDate(
      matching,
      takeoffs: (e) => e.nightTakeoffs,
      landings: (e) => e.nightLandings,
    );
    return _ninetyDayRule(
      id: RuleId.nightPassengers,
      title: 'Passengers at night',
      cite: '14 CFR 61.57(b)',
      shortLabel: 'night passenger currency',
      required: flight.passengers && flight.night,
      flight: flight,
      anchor: anchor,
      window: matching,
      takeoffs: (e) => e.nightTakeoffs,
      landings: (e) => e.nightLandings,
      need: (t, l) => _needText(t, l, 'night full-stop landings',
          'in ${_withArticle(cc.isEmpty ? 'aircraft with no category/class' : cc)} '
              'before carrying passengers at night',
          takeoffWord: 'night takeoffs'),
      notes: _unclassifiedNote(usable, flight),
    );
  }

  /// The date of the oldest takeoff/landing still needed to make three of
  /// each, counting back from the newest entry. Null when there are fewer
  /// than three of either on record.
  DateTime? _anchorDate(
    List<LogbookEntry> newestFirst, {
    required int Function(LogbookEntry) takeoffs,
    required int Function(LogbookEntry) landings,
  }) {
    DateTime? t, l;
    var tc = 0, lc = 0;
    for (final e in newestFirst) {
      if (t == null) {
        tc += takeoffs(e);
        if (tc >= 3) t = e.day;
      }
      if (l == null) {
        lc += landings(e);
        if (lc >= 3) l = e.day;
      }
      if (t != null && l != null) break;
    }
    if (t == null || l == null) return null;
    return t.isBefore(l) ? t : l;
  }

  RuleStatus _ninetyDayRule({
    required RuleId id,
    required String title,
    required String cite,
    required String shortLabel,
    required bool required,
    required PlannedFlight flight,
    required DateTime? anchor,
    required List<LogbookEntry> window,
    required int Function(LogbookEntry) takeoffs,
    required int Function(LogbookEntry) landings,
    required String Function(int t, int l) need,
    List<String> notes = const [],
  }) {
    final f = flight.day;
    // What is on record inside the 90 days before the flight.
    var t = 0, l = 0;
    for (final e in window) {
      final age = daysBetween(e.day, f);
      if (age >= 0 && age <= 90) {
        t += takeoffs(e);
        l += landings(e);
      }
    }
    final shortT = (3 - t).clamp(0, 3);
    final shortL = (3 - l).clamp(0, 3);

    if (anchor == null) {
      return RuleStatus(
        id: id,
        title: title,
        cite: cite,
        shortLabel: shortLabel,
        required: required,
        state: window.isEmpty ? RuleState.unknown : RuleState.lapsed,
        summary: window.isEmpty
            ? 'Nothing logged that counts yet'
            : 'Fewer than 3 takeoffs and 3 landings on record',
        shortfall: need(shortT, shortL),
        notes: notes,
      );
    }
    final through = addDays(anchor, 90);
    final ok = !f.isAfter(through);
    return RuleStatus(
      id: id,
      title: title,
      cite: cite,
      shortLabel: shortLabel,
      required: required,
      state: ok ? RuleState.valid : RuleState.lapsed,
      validThrough: through,
      summary: ok
          ? 'Valid through ${dayMonthYear(through)}'
          : 'Lapsed on ${dayMonthYear(addDays(through, 1))}',
      shortfall: ok ? null : need(shortT, shortL),
      notes: notes,
    );
  }

  String _needText(int t, int l, String landingWord, String tail,
      {String takeoffWord = 'takeoffs'}) {
    final parts = <String>[
      if (t > 0) '$t more ${t == 1 ? takeoffWord.replaceAll(RegExp(r's$'), '') : takeoffWord}',
      if (l > 0) '$l more ${l == 1 ? landingWord.replaceAll(RegExp(r's$'), '') : landingWord}',
    ];
    return 'Need ${parts.join(' and ')} within 90 days $tail.';
  }

  String _withArticle(String noun) =>
      '${'AEIOUaeiou'.contains(noun[0]) ? 'an' : 'a'} $noun';

  List<String> _unclassifiedNote(List<LogbookEntry> usable, PlannedFlight f) {
    final n = usable
        .where((e) =>
            e.categoryClass.trim().isEmpty &&
            daysBetween(e.day, f.day) <= 90)
        .length;
    if (n == 0) return const [];
    return [
      '$n recent ${n == 1 ? 'entry has' : 'entries have'} no category/class '
          'and cannot count. Edit ${n == 1 ? 'it' : 'them'} in the Logbook.'
    ];
  }

  // ── 61.57(c) and (d) ───────────────────────────────────────────────────

  /// 61.57(c)(1): "Within the 6 calendar months preceding the month of the
  /// flight, that person performed and logged at least the following tasks
  /// and iterations in an airplane, powered-lift, helicopter, or airship, as
  /// appropriate, for the instrument rating privileges to be maintained ...
  /// (i) Six instrument approaches. (ii) Holding procedures and tasks.
  /// (iii) Intercepting and tracking courses through the use of navigational
  /// electronic systems."
  ///
  /// 61.57(d)(1): "a person who has failed to meet the instrument experience
  /// requirements of paragraph (c) of this section for more than six calendar
  /// months may reestablish instrument currency only by completing an
  /// instrument proficiency check."
  ///
  /// Each task flown in month T is good for flights through the end of month
  /// T+6, and tasks already flown in the month of the flight count (the
  /// common reading, which every e-logbook we know of uses). An entry flagged
  /// IPC is good through the end of the 6th calendar month after its month.
  /// Before the first logged IPC the engine assumes the pilot was current when
  /// the logbook starts, because it cannot know otherwise; that assumption is
  /// stated on the card.
  RuleStatus _ifr(
      List<LogbookEntry> usable, PlannedFlight flight, PilotProfile profile) {
    const cite = '14 CFR 61.57(c), (d)';
    const label = 'IFR currency';
    if (!profile.instrumentRated) {
      return RuleStatus(
        id: RuleId.ifr,
        title: 'IFR',
        cite: cite,
        shortLabel: 'instrument rating',
        required: flight.ifr,
        state: RuleState.unknown,
        summary: 'No instrument rating in your profile',
        shortfall: flight.ifr
            ? 'If you hold an instrument rating, turn it on in Settings.'
            : null,
      );
    }
    final category = _category(flight.categoryClass);
    final oldestFirst = usable
        .where((e) => _category(e.categoryClass) == category && category != '')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    DateTime? through; // currency valid through (inclusive)
    var lockedOut = false;
    final seen = <LogbookEntry>[];
    for (final e in oldestFirst) {
      seen.add(e);
      if (through != null && e.day.isAfter(_graceEnd(through))) {
        lockedOut = true;
      }
      if (e.ipc) {
        lockedOut = false;
        final ipcThrough = endOfMonthAfter(e.day, 6);
        through = _later(through, ipcThrough);
      }
      if (!lockedOut) {
        through = _later(through, _tasksThrough(seen));
      }
    }

    final f = flight.day;
    // What is on record in the window for this flight's month.
    final windowStart = startOfMonthAfter(f, -6);
    var approaches = 0;
    var holding = false, tracking = false;
    for (final e in oldestFirst) {
      if (e.day.isBefore(windowStart)) continue;
      approaches += e.approaches;
      holding = holding || e.holding;
      tracking = tracking || e.tracking;
    }
    String needTasks() {
      final parts = <String>[
        if (approaches < 6) '${6 - approaches} more approach${6 - approaches == 1 ? '' : 'es'}',
        if (!holding) 'holding',
        if (!tracking) 'intercepting and tracking courses',
      ];
      return parts.isEmpty ? '' : parts.join(', ');
    }

    final notes = <String>[
      if (!oldestFirst.any((e) => e.ipc))
        'Assumes you were IFR current when this logbook starts; log an IPC to '
            'anchor it.',
    ];

    if (through == null) {
      return RuleStatus(
        id: RuleId.ifr,
        title: 'IFR',
        cite: cite,
        shortLabel: label,
        required: flight.ifr,
        state: oldestFirst.isEmpty ? RuleState.unknown : RuleState.lapsed,
        summary: oldestFirst.isEmpty
            ? 'No approaches, holds or tracking logged yet'
            : 'Not yet 6 approaches, holding and tracking on record',
        shortfall: 'Need ${needTasks()} within 6 calendar months, in '
            '${_withArticle(category.isEmpty ? 'aircraft with no category/class' : category.toLowerCase())}.',
        notes: notes,
      );
    }
    if (!f.isAfter(through)) {
      return RuleStatus(
        id: RuleId.ifr,
        title: 'IFR',
        cite: cite,
        shortLabel: label,
        required: flight.ifr,
        state: RuleState.valid,
        validThrough: through,
        summary: 'Valid through ${dayMonthYear(through)}',
        notes: notes,
      );
    }
    final graceEnd = _graceEnd(through);
    final inGrace = !lockedOut && !f.isAfter(graceEnd);
    final lapsed = addDays(through, 1);
    return RuleStatus(
      id: RuleId.ifr,
      title: 'IFR',
      cite: cite,
      shortLabel: label,
      required: flight.ifr,
      state: inGrace ? RuleState.grace : RuleState.ipcRequired,
      validThrough: through,
      summary: 'Lapsed on ${dayMonthYear(lapsed)}',
      shortfall: inGrace
          ? 'Until ${dayMonthYear(graceEnd)} you can regain it with a safety '
              'pilot: ${needTasks().isEmpty ? '6 approaches, holding and tracking' : needTasks()}. '
              'After that an IPC is required.'
          : 'More than 6 calendar months since it lapsed: an instrument '
              'proficiency check (61.57(d)) is required.',
      notes: notes,
    );
  }

  /// End of the six calendar months after the month currency lapsed in.
  DateTime _graceEnd(DateTime through) => endOfMonthAfter(through, 6);

  DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  /// Currency from tasks alone, using every entry in [seen]: the month of the
  /// 6th most recent approach, the latest holding and the latest tracking —
  /// whichever is oldest — plus six calendar months.
  DateTime? _tasksThrough(List<LogbookEntry> seen) {
    final newestFirst = seen.reversed;
    DateTime? sixth, hold, track;
    var count = 0;
    for (final e in newestFirst) {
      if (sixth == null && e.approaches > 0) {
        count += e.approaches;
        if (count >= 6) sixth = e.day;
      }
      if (hold == null && e.holding) hold = e.day;
      if (track == null && e.tracking) track = e.day;
    }
    if (sixth == null || hold == null || track == null) return null;
    var oldest = sixth;
    if (hold.isBefore(oldest)) oldest = hold;
    if (track.isBefore(oldest)) oldest = track;
    return endOfMonthAfter(oldest, 6);
  }

  String _category(String cc) {
    final c = cc.trim().toUpperCase();
    if (CategoryClass.presets.contains(c)) return 'AIRPLANE';
    return c;
  }

  // ── 61.56 ──────────────────────────────────────────────────────────────

  /// 61.56(c): "no person may act as pilot in command of an aircraft unless,
  /// since the beginning of the 24th calendar month before the month in which
  /// that pilot acts as pilot in command, that person has— (1) Accomplished a
  /// flight review ..." 61.56(d)(1): a pilot proficiency check or practical
  /// test for a certificate, rating or operating privilege also counts.
  /// 61.56(g): "A student pilot need not accomplish the flight review ...
  /// provided the student pilot is undergoing training for a certificate and
  /// has a current solo flight endorsement as required under § 61.87."
  RuleStatus _flightReview(
      List<LogbookEntry> usable, PlannedFlight flight, PilotProfile profile) {
    const cite = '14 CFR 61.56';
    final f = flight.day;
    if (profile.studentPilot && _soloCurrent(profile, f)) {
      return const RuleStatus(
        id: RuleId.flightReview,
        title: 'Flight review',
        cite: cite,
        shortLabel: 'flight review',
        required: true,
        state: RuleState.exempt,
        summary: 'Not required: student with a current solo endorsement '
            '(61.56(g))',
      );
    }
    DateTime? latest = profile.flightReviewDate == null
        ? null
        : dateOnly(profile.flightReviewDate!);
    for (final e in usable) {
      if ((e.flightReview || e.practicalTest) &&
          (latest == null || e.day.isAfter(latest))) {
        latest = e.day;
      }
    }
    if (latest == null) {
      return const RuleStatus(
        id: RuleId.flightReview,
        title: 'Flight review',
        cite: cite,
        shortLabel: 'flight review',
        required: true,
        state: RuleState.unknown,
        summary: 'No flight review on record',
        shortfall: 'Add your last flight review date in Settings, or log a '
            'flight flagged "Flight review".',
      );
    }
    final through = endOfMonthAfter(latest, 24);
    final ok = !f.isAfter(through);
    return RuleStatus(
      id: RuleId.flightReview,
      title: 'Flight review',
      cite: cite,
      shortLabel: 'flight review',
      required: true,
      state: ok ? RuleState.valid : RuleState.lapsed,
      validThrough: through,
      summary: ok
          ? 'Valid through ${dayMonthYear(through)}'
          : 'Lapsed on ${dayMonthYear(addDays(through, 1))}',
      shortfall: ok
          ? null
          : 'Need a flight review with an authorized instructor before acting '
              'as PIC.',
    );
  }

  // ── 61.23 ──────────────────────────────────────────────────────────────

  RuleStatus _medical(PlannedFlight flight, PilotProfile profile) {
    const cite = '14 CFR 61.23';
    final f = flight.day;
    switch (profile.medicalKind) {
      case MedicalKind.none:
        return const RuleStatus(
          id: RuleId.medical,
          title: 'Medical',
          cite: cite,
          shortLabel: 'medical',
          required: true,
          state: RuleState.unknown,
          summary: 'No medical on record',
          shortfall: 'Add your medical class and exam date, or BasicMed, in '
              'Settings.',
        );
      case MedicalKind.basicMed:
        return _basicMed(f, profile);
      case MedicalKind.first:
      case MedicalKind.second:
      case MedicalKind.third:
        final exam = profile.medicalExamDate;
        if (exam == null) {
          return RuleStatus(
            id: RuleId.medical,
            title: 'Medical',
            cite: cite,
            shortLabel: 'medical',
            required: true,
            state: RuleState.unknown,
            summary: '${profile.medicalKind.label}: no exam date',
            shortfall: 'Add the exam date shown on your medical certificate.',
          );
        }
        final age = profile.age40OrOlderAtExam;
        final through = medicalValidThrough(
          kind: profile.medicalKind,
          examDate: exam,
          age40OrOlder: age ?? true,
          privilege: profile.privilege,
        );
        final notes = <String>[
          if (age == null)
            'Age on the exam date not answered, so the shorter (40 or older) '
                'duration is used.',
        ];
        if (through == null) {
          return RuleStatus(
            id: RuleId.medical,
            title: 'Medical',
            cite: cite,
            shortLabel: 'medical',
            required: true,
            state: RuleState.lapsed,
            summary: '${profile.medicalKind.label} does not cover '
                '${profile.privilege.label.toLowerCase()} privileges',
            shortfall: 'A higher class of medical is required for those '
                'privileges (61.23(a)).',
            notes: notes,
          );
        }
        final ok = !f.isAfter(through);
        return RuleStatus(
          id: RuleId.medical,
          title: 'Medical',
          cite: '14 CFR 61.23(d)',
          shortLabel: 'medical',
          required: true,
          state: ok ? RuleState.valid : RuleState.lapsed,
          validThrough: through,
          summary: ok
              ? '${profile.medicalKind.label}: valid through '
                  '${dayMonthYear(through)}'
              : '${profile.medicalKind.label}: lapsed on '
                  '${dayMonthYear(addDays(through, 1))}',
          shortfall: ok ? null : 'Need a new medical examination.',
          notes: notes,
        );
    }
  }

  /// 61.23(c)(3)(i): "(C) Complete the medical education course ... during
  /// the 24 calendar months before acting as pilot in command ... (D) Receive
  /// a comprehensive medical examination from a State-licensed physician
  /// during the 48 calendar months before acting as pilot in command".
  /// BasicMed covers private, recreational, student and CFI privileges only
  /// (61.23(a)(3)), so commercial or ATP privileges are refused.
  RuleStatus _basicMed(DateTime f, PilotProfile profile) {
    const cite = '14 CFR 61.23(c)(3)';
    if (profile.privilege != MedicalPrivilege.third) {
      return RuleStatus(
        id: RuleId.medical,
        title: 'Medical (BasicMed)',
        cite: cite,
        shortLabel: 'medical',
        required: true,
        state: RuleState.lapsed,
        summary: 'BasicMed does not cover '
            '${profile.privilege.label.toLowerCase()} privileges',
        shortfall: 'Those privileges need a medical certificate (61.23(a)).',
      );
    }
    final exam = profile.basicMedExamDate;
    final course = profile.basicMedCourseDate;
    if (exam == null || course == null) {
      return RuleStatus(
        id: RuleId.medical,
        title: 'Medical (BasicMed)',
        cite: cite,
        shortLabel: 'BasicMed',
        required: true,
        state: RuleState.unknown,
        summary: exam == null
            ? 'No comprehensive medical exam date'
            : 'No medical education course date',
        shortfall: 'Add both BasicMed dates in Settings.',
      );
    }
    final examThrough = endOfMonthAfter(exam, 48);
    final courseThrough = endOfMonthAfter(course, 24);
    final through =
        examThrough.isBefore(courseThrough) ? examThrough : courseThrough;
    final limiting = examThrough.isBefore(courseThrough)
        ? 'comprehensive medical exam (48 calendar months)'
        : 'medical education course (24 calendar months)';
    final ok = !f.isAfter(through);
    return RuleStatus(
      id: RuleId.medical,
      title: 'Medical (BasicMed)',
      cite: cite,
      shortLabel: 'BasicMed',
      required: true,
      state: ok ? RuleState.valid : RuleState.lapsed,
      validThrough: through,
      summary: ok
          ? 'BasicMed: valid through ${dayMonthYear(through)}'
          : 'BasicMed: lapsed on ${dayMonthYear(addDays(through, 1))}',
      shortfall: ok ? null : 'Renew the $limiting.',
      notes: [
        'Limited by the $limiting.',
        'BasicMed operating limits (61.113(i)) are not checked here.',
      ],
    );
  }

  // ── Student pilots ─────────────────────────────────────────────────────

  bool _soloCurrent(PilotProfile p, DateTime f) {
    final d = p.soloEndorsementDate;
    if (d == null) return false;
    final age = daysBetween(dateOnly(d), f);
    return age >= 0 && age <= 90;
  }

  /// 61.87(n): "A student pilot may not operate an aircraft in solo flight
  /// unless that student pilot has received an endorsement in the student's
  /// logbook for the specific make and model aircraft to be flown by an
  /// authorized instructor who gave the training within the 90 days preceding
  /// the date of the flight."
  RuleStatus _studentSolo(PlannedFlight flight, PilotProfile profile) {
    const cite = '14 CFR 61.87(n)';
    final d = profile.soloEndorsementDate;
    if (d == null) {
      return const RuleStatus(
        id: RuleId.studentSolo,
        title: 'Solo endorsement',
        cite: cite,
        shortLabel: 'solo endorsement',
        required: true,
        state: RuleState.unknown,
        summary: 'No solo endorsement date',
        shortfall: 'Add the date of your instructor\'s 90-day solo '
            'endorsement in Settings.',
      );
    }
    final through = addDays(dateOnly(d), 90);
    final ok = _soloCurrent(profile, flight.day);
    return RuleStatus(
      id: RuleId.studentSolo,
      title: 'Solo endorsement',
      cite: cite,
      shortLabel: 'solo endorsement',
      required: true,
      state: ok ? RuleState.valid : RuleState.lapsed,
      validThrough: through,
      summary: ok
          ? 'Valid through ${dayMonthYear(through)}'
          : 'Lapsed on ${dayMonthYear(addDays(through, 1))}',
      shortfall: ok ? null : 'Need a new solo endorsement from your instructor.',
    );
  }

  /// 61.89(a)(1): a student pilot may not act as pilot in command of an
  /// aircraft that is carrying a passenger.
  RuleStatus _studentPassengers(PlannedFlight flight) {
    return RuleStatus(
      id: RuleId.studentPassengers,
      title: 'Student pilot with passengers',
      cite: '14 CFR 61.89(a)(1)',
      shortLabel: 'passenger privilege',
      required: flight.passengers,
      state: flight.passengers ? RuleState.lapsed : RuleState.exempt,
      summary: flight.passengers
          ? 'Student pilots may not carry passengers'
          : 'No passengers on this flight',
      shortfall: flight.passengers
          ? 'Fly this one without passengers.'
          : null,
    );
  }
}
