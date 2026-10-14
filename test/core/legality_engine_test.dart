/// The legality engine against the regulation text (eCFR, fetched
/// 2026-10-14). Every date is fixed; nothing reads the system clock.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';

LogbookEntry e(
  DateTime date, {
  String cc = 'ASEL',
  bool tailwheel = false,
  int dayTo = 0,
  int dayLdg = 0,
  int dayFullStop = 0,
  int nightTo = 0,
  int nightLdg = 0,
  int approaches = 0,
  bool holding = false,
  bool tracking = false,
  bool flightReview = false,
  bool ipc = false,
  bool practicalTest = false,
}) =>
    LogbookEntry(
      date: date,
      aircraftType: 'C172',
      tailNumber: 'N1',
      from: 'KPAO',
      to: 'KPAO',
      totalTime: 1.0,
      categoryClass: cc,
      tailwheel: tailwheel,
      dayTakeoffs: dayTo,
      dayLandings: dayLdg,
      dayFullStopLandings: dayFullStop,
      nightTakeoffs: nightTo,
      nightLandings: nightLdg,
      approaches: approaches,
      holding: holding,
      tracking: tracking,
      flightReview: flightReview,
      ipc: ipc,
      practicalTest: practicalTest,
    );

/// A profile with everything else valid, so a test isolates one rule.
final validProfile = PilotProfile(
  medicalKind: MedicalKind.third,
  medicalExamDate: DateTime(2026, 1, 10),
  age40OrOlderAtExam: false,
  flightReviewDate: DateTime(2026, 1, 10),
  instrumentRated: true,
  homeCategoryClass: 'ASEL',
);

LegalityReport run(
  List<LogbookEntry> entries,
  DateTime flight, {
  PilotProfile? profile,
  String cc = 'ASEL',
  bool tailwheel = false,
  bool passengers = true,
  bool night = false,
  bool ifr = false,
}) =>
    const LegalityEngine().evaluate(
      entries: entries,
      profile: profile ?? validProfile,
      flight: PlannedFlight(
        date: flight,
        categoryClass: cc,
        tailwheel: tailwheel,
        passengers: passengers,
        night: night,
        ifr: ifr,
      ),
    );

void main() {
  final oct14 = DateTime(2026, 10, 14, 9, 30);

  group('61.57(a) day passenger currency', () {
    test('61.57(a): landings 90 days before the flight still count', () {
      // 16 Jul -> 14 Oct 2026 is 90 days.
      final r = run([e(DateTime(2026, 7, 16), dayTo: 3, dayLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 10, 14));
      expect(r.summary, 'Valid through 14 Oct 2026');
    });

    test('61.57(a): landings 91 days before the flight do not', () {
      final r = run([e(DateTime(2026, 7, 15), dayTo: 3, dayLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.lapsed);
      expect(r.validThrough, DateTime(2026, 10, 13));
      expect(r.lapsedOn, DateTime(2026, 10, 14));
      expect(r.summary, 'Lapsed on 14 Oct 2026');
      expect(r.blocks, isTrue);
    });

    test('61.57(a): night landings count toward day currency', () {
      final r = run([e(DateTime(2026, 9, 1), nightTo: 3, nightLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 11, 30));
    });

    test('61.57(a): takeoffs and landings add up across flights', () {
      final r = run([
        e(DateTime(2026, 9, 1), dayTo: 1, dayLdg: 1),
        e(DateTime(2026, 9, 20), dayTo: 2, dayLdg: 2),
      ], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
      // The oldest of the three still needed is 1 Sep.
      expect(r.validThrough, DateTime(2026, 11, 30));
    });

    test('61.57(a): the newest three keep it going, older ones are spare', () {
      final r = run([
        e(DateTime(2026, 5, 1), dayTo: 3, dayLdg: 3),
        e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3),
      ], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.validThrough, DateTime(2026, 12, 30));
    });

    test('61.57(a): three landings but two takeoffs is not current', () {
      final r = run([e(DateTime(2026, 10, 1), dayTo: 2, dayLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.lapsed);
      expect(r.shortfall,
          'Need 1 more takeoff within 90 days in an ASEL before carrying '
          'passengers.');
    });

    test('61.57(a): the shortfall names what is missing', () {
      final r = run([e(DateTime(2026, 10, 1), dayTo: 1, dayLdg: 1)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.shortfall,
          'Need 2 more takeoffs and 2 more landings within 90 days in an ASEL '
          'before carrying passengers.');
    });

    test('61.57(a)(1)(ii): another category/class does not count', () {
      final r = run([e(DateTime(2026, 10, 1), cc: 'AMEL', dayTo: 3, dayLdg: 3)],
              oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.unknown);
      expect(r.blocks, isTrue);
    });

    test('61.57(a)(1)(ii): AMEL landings make an AMEL pilot current', () {
      final r = run([e(DateTime(2026, 10, 1), cc: 'AMEL', dayTo: 3, dayLdg: 3)],
              oct14,
              cc: 'AMEL')
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a): class matching ignores case and spaces', () {
      final r = run([e(DateTime(2026, 10, 1), cc: ' asel', dayTo: 3, dayLdg: 3)],
              oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a): entries with no class cannot count and say so', () {
      final r = run([e(DateTime(2026, 10, 1), cc: '', dayTo: 3, dayLdg: 3)],
              oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, isNot(RuleState.valid));
      expect(r.notes.single, contains('1 recent entry has no category/class'));
    });

    test('61.57(a)(1)(ii) tailwheel: touch-and-goes do not count', () {
      final r = run([
        e(DateTime(2026, 10, 1), tailwheel: true, dayTo: 3, dayLdg: 3),
      ], oct14, tailwheel: true)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.lapsed);
      expect(r.shortfall, contains('3 more full-stop landings'));
      expect(r.shortfall, contains('a tailwheel ASEL'));
    });

    test('61.57(a)(1)(ii) tailwheel: full stops in a tailwheel count', () {
      final r = run([
        e(DateTime(2026, 10, 1),
            tailwheel: true, dayTo: 3, dayLdg: 3, dayFullStop: 3),
      ], oct14, tailwheel: true)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a)(1)(ii) tailwheel: night landings are full stops', () {
      final r = run([
        e(DateTime(2026, 10, 1), tailwheel: true, nightTo: 3, nightLdg: 3),
      ], oct14, tailwheel: true)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a)(1)(ii) tailwheel: full stops in a nosewheel do not count',
        () {
      final r = run([
        e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3, dayFullStop: 3),
      ], oct14, tailwheel: true)
          .rule(RuleId.dayPassengers);
      expect(r.state, isNot(RuleState.valid));
    });

    test('61.57(a): tailwheel landings count for a nosewheel flight', () {
      final r = run([
        e(DateTime(2026, 10, 1), tailwheel: true, dayTo: 3, dayLdg: 3),
      ], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a): the 90 days run across a year end', () {
      // 1 Dec 2025 + 90 days = 1 Mar 2026.
      final r = run([e(DateTime(2025, 12, 1), dayTo: 3, dayLdg: 3)],
              DateTime(2026, 2, 28))
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 3, 1));
      final late = run([e(DateTime(2025, 12, 1), dayTo: 3, dayLdg: 3)],
              DateTime(2026, 3, 2))
          .rule(RuleId.dayPassengers);
      expect(late.state, RuleState.lapsed);
    });

    test('61.57(a): a flight logged after the planned date cannot count', () {
      final r = run([e(DateTime(2026, 10, 20), dayTo: 3, dayLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.unknown);
    });

    test('61.57(a): landings earlier on the day of the flight count', () {
      final r = run([e(DateTime(2026, 10, 14, 7), dayTo: 3, dayLdg: 3)], oct14)
          .rule(RuleId.dayPassengers);
      expect(r.state, RuleState.valid);
    });

    test('61.57(a): without passengers it is shown but does not block', () {
      final rep = run([], oct14, passengers: false);
      final r = rep.rule(RuleId.dayPassengers);
      expect(r.required, isFalse);
      expect(r.blocks, isFalse);
      expect(rep.legal, isTrue);
    });

    test('61.57(a): an empty logbook with passengers is not legal', () {
      final rep = run([], oct14);
      expect(rep.hasEntries, isFalse);
      expect(rep.rule(RuleId.dayPassengers).state, RuleState.unknown);
      expect(rep.legal, isFalse);
      expect(rep.notLegalLine, 'Not legal: passenger currency not on record');
    });
  });

  group('61.57(b) night passenger currency', () {
    test('61.57(b): three night takeoffs and full-stop landings make it', () {
      final r = run([e(DateTime(2026, 9, 1), nightTo: 3, nightLdg: 3)], oct14,
              night: true)
          .rule(RuleId.nightPassengers);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 11, 30));
    });

    test('61.57(b): day landings do not count at night', () {
      final r = run([e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3)], oct14,
              night: true)
          .rule(RuleId.nightPassengers);
      expect(r.state, isNot(RuleState.valid));
      expect(r.blocks, isTrue);
      expect(r.shortfall,
          'Need 3 more night takeoffs and 3 more night full-stop landings '
          'within 90 days in an ASEL before carrying passengers at night.');
    });

    test('61.57(b): day 90 counts, day 91 does not', () {
      final in90 = run([e(DateTime(2026, 7, 16), nightTo: 3, nightLdg: 3)],
              oct14,
              night: true)
          .rule(RuleId.nightPassengers);
      final at91 = run([e(DateTime(2026, 7, 15), nightTo: 3, nightLdg: 3)],
              oct14,
              night: true)
          .rule(RuleId.nightPassengers);
      expect(in90.state, RuleState.valid);
      expect(at91.state, RuleState.lapsed);
    });

    test('61.57(b)(1)(ii): another class does not count', () {
      final r = run([
        e(DateTime(2026, 10, 1), cc: 'ASES', nightTo: 3, nightLdg: 3),
      ], oct14, night: true)
          .rule(RuleId.nightPassengers);
      expect(r.state, RuleState.unknown);
    });

    test('61.57(b): only required with passengers at night', () {
      final r = run([], oct14, night: false).rule(RuleId.nightPassengers);
      expect(r.required, isFalse);
      final solo = run([], oct14, night: true, passengers: false)
          .rule(RuleId.nightPassengers);
      expect(solo.required, isFalse);
    });

    test('61.57(b): the one-line result names the lapse date', () {
      final rep = run([
        e(DateTime(2026, 7, 3), nightTo: 3, nightLdg: 3), // through 1 Oct
        e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3),
      ], oct14, night: true);
      expect(rep.rule(RuleId.nightPassengers).lapsedOn, DateTime(2026, 10, 2));
      expect(rep.notLegalLine,
          'Not legal: night passenger currency lapsed 2 Oct');
    });
  });

  group('61.57(c)/(d) IFR currency', () {
    List<LogbookEntry> tasks(DateTime d, {String cc = 'ASEL'}) =>
        [e(d, cc: cc, approaches: 6, holding: true, tracking: true)];

    test('61.57(c)(1): tasks in April are good through 31 October', () {
      final r = run(tasks(DateTime(2026, 4, 20)), DateTime(2026, 10, 31),
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 10, 31));
    });

    test('61.57(c)(1): six calendar months, not 180 days', () {
      // 180 days after 20 Apr is 17 Oct; calendar months run to 31 Oct.
      final r = run(tasks(DateTime(2026, 4, 20)), DateTime(2026, 10, 25),
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
    });

    test('61.57(c)(1): the window runs across a year end', () {
      final r = run(tasks(DateTime(2025, 11, 3)), DateTime(2026, 5, 31),
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 5, 31));
      final june = run(tasks(DateTime(2025, 11, 3)), DateTime(2026, 6, 1),
              ifr: true)
          .rule(RuleId.ifr);
      expect(june.state, RuleState.grace);
    });

    test('61.57(c)(1): the oldest approach needed sets the date', () {
      final r = run([
        e(DateTime(2026, 1, 10), approaches: 3),
        e(DateTime(2026, 3, 10), approaches: 3, holding: true, tracking: true),
      ], DateTime(2026, 6, 1), ifr: true)
          .rule(RuleId.ifr);
      expect(r.validThrough, DateTime(2026, 7, 31));
    });

    test('61.57(c)(1)(ii): no holding means not current', () {
      final r = run([e(DateTime(2026, 9, 1), approaches: 6, tracking: true)],
              oct14,
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.lapsed);
      expect(r.shortfall, contains('holding'));
      expect(r.blocks, isTrue);
    });

    test('61.57(c)(1)(i): five approaches are one short', () {
      final r = run([
        e(DateTime(2026, 9, 1), approaches: 5, holding: true, tracking: true)
      ], oct14, ifr: true)
          .rule(RuleId.ifr);
      expect(r.shortfall, contains('1 more approach'));
    });

    test('61.57(c): tasks flown earlier in the month of the flight count', () {
      final r = run(tasks(DateTime(2026, 10, 5)), oct14, ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2027, 4, 30));
    });

    test('61.57(d): lapsed, inside the six-month grace window', () {
      final r = run(tasks(DateTime(2026, 1, 15)), oct14, ifr: true)
          .rule(RuleId.ifr);
      // Valid through 31 Jul 2026; grace to 31 Jan 2027.
      expect(r.state, RuleState.grace);
      expect(r.lapsedOn, DateTime(2026, 8, 1));
      expect(r.shortfall, startsWith('Until 31 Jan 2027'));
      expect(r.blocks, isTrue);
    });

    test('61.57(d): more than six calendar months lapsed needs an IPC', () {
      final r = run(tasks(DateTime(2026, 1, 15)), DateTime(2027, 2, 1),
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.ipcRequired);
      final rep = run(tasks(DateTime(2026, 1, 15)), DateTime(2027, 2, 1),
          ifr: true, passengers: false);
      expect(rep.notLegalLine,
          'Not legal: IFR currency needs an instrument proficiency check');
    });

    test('61.57(d): tasks inside the grace window restore currency', () {
      final r = run([
        ...tasks(DateTime(2025, 1, 15)), // through 31 Jul 2025
        ...tasks(DateTime(2025, 10, 2)), // inside grace (to 31 Jan 2026)
      ], DateTime(2026, 3, 1), ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 4, 30));
    });

    test('61.57(d): tasks after the grace window do not, without an IPC', () {
      final r = run([
        ...tasks(DateTime(2025, 1, 15)), // grace ended 31 Jan 2026
        ...tasks(DateTime(2026, 3, 2)),
      ], DateTime(2026, 4, 1), ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.ipcRequired);
    });

    test('61.57(d): an IPC entry resets the clock', () {
      final r = run([
        ...tasks(DateTime(2025, 1, 15)),
        e(DateTime(2026, 4, 5), ipc: true),
      ], DateTime(2026, 4, 6), ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 10, 31));
    });

    test('61.57(d): an IPC with no other history is enough', () {
      final r = run([e(DateTime(2026, 6, 30), ipc: true)], oct14, ifr: true)
          .rule(RuleId.ifr);
      expect(r.validThrough, DateTime(2026, 12, 31));
      expect(r.notes, isEmpty);
    });

    test('61.57(c)(1): helicopter approaches do not keep an airplane current',
        () {
      final r = run(tasks(DateTime(2026, 9, 1), cc: 'Rotorcraft helicopter'),
              oct14,
              ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.unknown);
    });

    test('61.57(c)(1): multi-engine approaches keep an ASEL pilot current', () {
      final r = run(tasks(DateTime(2026, 9, 1), cc: 'AMEL'), oct14, ifr: true)
          .rule(RuleId.ifr);
      expect(r.state, RuleState.valid);
    });

    test('61.57(c): without an instrument rating IFR is refused', () {
      final r = run(tasks(DateTime(2026, 9, 1)), oct14,
              ifr: true,
              profile: validProfile.copyWith(instrumentRated: false))
          .rule(RuleId.ifr);
      expect(r.state, RuleState.unknown);
      expect(r.blocks, isTrue);
    });

    test('61.57(c): a VFR flight does not need IFR currency', () {
      final rep = run([e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3)], oct14);
      expect(rep.rule(RuleId.ifr).required, isFalse);
      expect(rep.legal, isTrue);
    });

    test('61.57(c): the assumption before any IPC is stated', () {
      final r = run(tasks(DateTime(2026, 9, 1)), oct14, ifr: true)
          .rule(RuleId.ifr);
      expect(r.notes.single, contains('Assumes you were IFR current'));
    });
  });

  group('61.56 flight review', () {
    test('61.56(c): 13 Oct 2026 is good through 31 Oct 2028', () {
      final r = run([], DateTime(2028, 10, 31),
              passengers: false,
              profile: validProfile.copyWith(
                  flightReviewDate: DateTime(2026, 10, 13)))
          .rule(RuleId.flightReview);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2028, 10, 31));
    });

    test('61.56(c): lapses on the first day of the 25th month', () {
      final r = run([], DateTime(2028, 11, 1),
              passengers: false,
              profile: validProfile.copyWith(
                  flightReviewDate: DateTime(2026, 10, 13)))
          .rule(RuleId.flightReview);
      expect(r.state, RuleState.lapsed);
      expect(r.summary, 'Lapsed on 1 Nov 2028');
    });

    test('61.56(c): a logged flight review newer than the profile wins', () {
      final r = run([e(DateTime(2026, 3, 2), flightReview: true)], oct14,
              passengers: false)
          .rule(RuleId.flightReview);
      expect(r.validThrough, DateTime(2028, 3, 31));
    });

    test('61.56(d)(1): a practical test counts as a flight review', () {
      final r = run([e(DateTime(2026, 5, 2), practicalTest: true)], oct14,
              passengers: false)
          .rule(RuleId.flightReview);
      expect(r.validThrough, DateTime(2028, 5, 31));
    });

    test('61.56(c): February review runs to a leap-year 29 Feb', () {
      final r = run([], DateTime(2028, 2, 29),
              passengers: false,
              profile: validProfile.copyWith(
                  flightReviewDate: DateTime(2026, 2, 10)))
          .rule(RuleId.flightReview);
      expect(r.validThrough, DateTime(2028, 2, 29));
      expect(r.state, RuleState.valid);
    });

    test('61.56: none on record blocks every flight', () {
      final rep = run([], oct14,
          passengers: false,
          profile: validProfile.copyWith(clearFlightReviewDate: true));
      expect(rep.rule(RuleId.flightReview).state, RuleState.unknown);
      expect(rep.legal, isFalse);
      expect(rep.notLegalLine, 'Not legal: flight review not on record');
    });

    test('61.56(g): a student with a current solo endorsement is exempt', () {
      final r = run([], oct14,
              passengers: false,
              profile: validProfile.copyWith(
                  clearFlightReviewDate: true,
                  studentPilot: true,
                  soloEndorsementDate: DateTime(2026, 9, 1)))
          .rule(RuleId.flightReview);
      expect(r.state, RuleState.exempt);
      expect(r.blocks, isFalse);
    });
  });

  group('61.23(d) medical duration', () {
    final exam = DateTime(2026, 3, 15);
    const cases = <(MedicalKind, MedicalPrivilege, bool, String?)>[
      // (1) first-class
      (MedicalKind.first, MedicalPrivilege.first, false, '2027-03-31'), // (1)(i) 12th
      (MedicalKind.first, MedicalPrivilege.first, true, '2026-09-30'), // (1)(ii) 6th
      (MedicalKind.first, MedicalPrivilege.second, false, '2027-03-31'), // (1)(iii)
      (MedicalKind.first, MedicalPrivilege.second, true, '2027-03-31'), // (1)(iii)
      (MedicalKind.first, MedicalPrivilege.third, false, '2031-03-31'), // (1)(iv) 60th
      (MedicalKind.first, MedicalPrivilege.third, true, '2028-03-31'), // (1)(v) 24th
      // (2) second-class
      (MedicalKind.second, MedicalPrivilege.first, false, null),
      (MedicalKind.second, MedicalPrivilege.first, true, null),
      (MedicalKind.second, MedicalPrivilege.second, false, '2027-03-31'), // (2)(i)
      (MedicalKind.second, MedicalPrivilege.second, true, '2027-03-31'), // (2)(i)
      (MedicalKind.second, MedicalPrivilege.third, false, '2031-03-31'), // (2)(ii)
      (MedicalKind.second, MedicalPrivilege.third, true, '2028-03-31'), // (2)(iii)
      // (3) third-class
      (MedicalKind.third, MedicalPrivilege.first, false, null),
      (MedicalKind.third, MedicalPrivilege.first, true, null),
      (MedicalKind.third, MedicalPrivilege.second, false, null),
      (MedicalKind.third, MedicalPrivilege.second, true, null),
      (MedicalKind.third, MedicalPrivilege.third, false, '2031-03-31'), // (3)(i)
      (MedicalKind.third, MedicalPrivilege.third, true, '2028-03-31'), // (3)(ii)
    ];
    for (final c in cases) {
      final age = c.$3 ? '40 or older' : 'under 40';
      test(
          '61.23(d): ${c.$1.name}-class, $age, ${c.$2.name}-class privileges '
          '-> ${c.$4 ?? 'not covered'}', () {
        final through = medicalValidThrough(
          kind: c.$1,
          examDate: exam,
          age40OrOlder: c.$3,
          privilege: c.$2,
        );
        expect(through, c.$4 == null ? isNull : DateTime.parse(c.$4!));
      });
    }

    test('61.23(d): valid on its last day, lapsed the next', () {
      PilotProfile p() => validProfile.copyWith(
          medicalKind: MedicalKind.third,
          medicalExamDate: exam,
          age40OrOlderAtExam: true);
      expect(
          run([], DateTime(2028, 3, 31), passengers: false, profile: p())
              .rule(RuleId.medical)
              .state,
          RuleState.valid);
      final r = run([], DateTime(2028, 4, 1), passengers: false, profile: p())
          .rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
      expect(r.summary, 'Third-class medical: lapsed on 1 Apr 2028');
    });

    test('61.23(d): an unanswered age uses the shorter duration and says so',
        () {
      final r = run([], oct14,
              passengers: false,
              profile: validProfile.copyWith(
                  medicalExamDate: exam, clearAge: true))
          .rule(RuleId.medical);
      expect(r.validThrough, DateTime(2028, 3, 31));
      expect(r.notes.single, contains('40 or older'));
    });

    test('61.23(a): a third-class medical refuses commercial privileges', () {
      final r = run([], oct14,
              passengers: false,
              profile: validProfile.copyWith(privilege: MedicalPrivilege.second))
          .rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
      expect(r.blocks, isTrue);
    });

    test('61.23: no medical on record blocks the flight', () {
      final rep = run([], oct14,
          passengers: false,
          profile: validProfile.copyWith(medicalKind: MedicalKind.none));
      expect(rep.rule(RuleId.medical).state, RuleState.unknown);
      expect(rep.legal, isFalse);
    });

    test('61.23: a class without an exam date is not assumed valid', () {
      final r = run([], oct14,
              passengers: false,
              profile: validProfile.copyWith(clearMedicalExamDate: true))
          .rule(RuleId.medical);
      expect(r.state, RuleState.unknown);
    });
  });

  group('61.23(c)(3) BasicMed', () {
    PilotProfile bm({DateTime? exam, DateTime? course, MedicalPrivilege? p}) =>
        validProfile.copyWith(
          medicalKind: MedicalKind.basicMed,
          basicMedExamDate: exam,
          basicMedCourseDate: course,
          privilege: p,
        );

    test('61.23(c)(3)(i)(D): the exam is good for 48 calendar months', () {
      final r = run([], DateTime(2027, 5, 31),
              passengers: false,
              profile: bm(
                  exam: DateTime(2023, 5, 20), course: DateTime(2026, 1, 5)))
          .rule(RuleId.medical);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2027, 5, 31));
      expect(r.notes.first, contains('comprehensive medical exam'));
    });

    test('61.23(c)(3)(i)(D): and lapses the day after', () {
      final r = run([], DateTime(2027, 6, 1),
              passengers: false,
              profile: bm(
                  exam: DateTime(2023, 5, 20), course: DateTime(2026, 1, 5)))
          .rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
    });

    test('61.23(c)(3)(i)(C): the course is good for 24 calendar months', () {
      final r = run([], oct14,
              passengers: false,
              profile:
                  bm(exam: DateTime(2026, 1, 5), course: DateTime(2025, 9, 1)))
          .rule(RuleId.medical);
      expect(r.validThrough, DateTime(2027, 9, 30));
      expect(r.notes.first, contains('medical education course'));
    });

    test('61.23(c)(3): a missing date is not assumed', () {
      final r = run([], oct14,
              passengers: false, profile: bm(exam: DateTime(2026, 1, 5)))
          .rule(RuleId.medical);
      expect(r.state, RuleState.unknown);
    });

    test('61.23(a): BasicMed does not cover commercial privileges', () {
      final r = run([], oct14,
              passengers: false,
              profile: bm(
                  exam: DateTime(2026, 1, 5),
                  course: DateTime(2026, 1, 5),
                  p: MedicalPrivilege.second))
          .rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
    });
  });

  group('student pilots', () {
    PilotProfile student(DateTime? solo) => validProfile.copyWith(
        studentPilot: true, soloEndorsementDate: solo);

    test('61.87(n): an endorsement 90 days before the flight is current', () {
      final r = run([], oct14,
              passengers: false, profile: student(DateTime(2026, 7, 16)))
          .rule(RuleId.studentSolo);
      expect(r.state, RuleState.valid);
      expect(r.validThrough, DateTime(2026, 10, 14));
    });

    test('61.87(n): 91 days is not', () {
      final r = run([], oct14,
              passengers: false, profile: student(DateTime(2026, 7, 15)))
          .rule(RuleId.studentSolo);
      expect(r.state, RuleState.lapsed);
    });

    test('61.87(n): no endorsement date is not assumed', () {
      final r = run([], oct14, passengers: false, profile: student(null))
          .rule(RuleId.studentSolo);
      expect(r.state, RuleState.unknown);
    });

    test('61.89(a)(1): a student may not carry passengers', () {
      final rep = run([e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3)], oct14,
          profile: student(DateTime(2026, 10, 1)));
      expect(rep.rule(RuleId.studentPassengers).blocks, isTrue);
      expect(rep.legal, isFalse);
    });

    test('61.89(a)(1): solo, a current student is legal', () {
      final rep = run([], oct14,
          passengers: false, profile: student(DateTime(2026, 10, 1)));
      expect(rep.legal, isTrue);
    });
  });

  group('the whole report', () {
    test('everything valid is legal and has no not-legal line', () {
      final rep = run([e(DateTime(2026, 10, 1), dayTo: 3, dayLdg: 3)], oct14);
      expect(rep.legal, isTrue);
      expect(rep.notLegalLine, isNull);
      expect(rep.firstBlocking, isNull);
    });

    test('every rule carries its regulation cite', () {
      final rep = run([], oct14);
      for (final r in rep.rules) {
        expect(r.cite, startsWith('14 CFR 61.'));
      }
    });
  });
}
