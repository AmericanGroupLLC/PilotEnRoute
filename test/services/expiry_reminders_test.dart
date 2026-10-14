/// Lapse reminders: 30 and 7 days before every date the legality engine
/// works out (medical, flight review, the three 61.57 items, a student's
/// solo endorsement) and before document expiries.
///
/// This replaces the old Profile-only medical/flight-review reminder (90/30/
/// 7/1 days before a hand-typed expiry). The scenarios that file covered are
/// all still here: ids are stable, the reschedule cancels old reminders
/// first, a refused permission schedules nothing and says so, and a platform
/// failure is never reported as a scheduled reminder.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/reminders/reminder_plan.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/notification_service.dart';
import 'package:pilot_enroute/services/reminder_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);

  final profile = PilotProfile(
    medicalKind: MedicalKind.third,
    medicalExamDate: DateTime(2025, 3, 10), // 40+: through 31 Mar 2027
    age40OrOlderAtExam: true,
    flightReviewDate: DateTime(2025, 2, 3), // through 28 Feb 2027
    instrumentRated: true,
    homeCategoryClass: 'ASEL',
  );

  final entries = [
    LogbookEntry(
      date: DateTime(2026, 10, 1),
      aircraftType: 'C172',
      tailNumber: 'N1',
      from: 'KPAO',
      to: 'KPAO',
      totalTime: 1.5,
      categoryClass: 'ASEL',
      dayTakeoffs: 3,
      dayLandings: 3, // day passengers through 30 Dec 2026
      nightTakeoffs: 3,
      nightLandings: 3, // night passengers through 30 Dec 2026
      approaches: 6,
      holding: true,
      tracking: true, // IFR through 30 Apr 2027
    ),
  ];

  void resetSeams() {
    NotificationService.permissionRequester =
        NotificationService.requestPermissions;
    NotificationService.permissionChecker =
        NotificationService.currentPermission;
  }

  tearDown(resetSeams);

  group('lapse dates from the engine', () {
    test('medical, flight review and all three 61.57 items', () {
      final items = lapseItemsFrom(entries: entries, profile: profile, now: now);
      final byKind = {for (final i in items) i.kind: i.validThrough};
      expect(byKind[ReminderKind.medical], DateTime(2027, 3, 31));
      expect(byKind[ReminderKind.flightReview], DateTime(2027, 2, 28));
      expect(byKind[ReminderKind.dayPassengers], DateTime(2026, 12, 30));
      expect(byKind[ReminderKind.nightPassengers], DateTime(2026, 12, 30));
      expect(byKind[ReminderKind.ifr], DateTime(2027, 4, 30));
    });

    test('IFR is left out for a pilot without an instrument rating', () {
      final items = lapseItemsFrom(
          entries: entries,
          profile: profile.copyWith(instrumentRated: false),
          now: now);
      expect(items.map((i) => i.kind), isNot(contains(ReminderKind.ifr)));
    });

    test('something already lapsed gets no reminder', () {
      final items =
          lapseItemsFrom(entries: const [], profile: profile, now: now);
      expect(items.map((i) => i.kind),
          isNot(contains(ReminderKind.dayPassengers)));
    });

    test('a student\'s solo endorsement is included', () {
      final items = lapseItemsFrom(
          entries: entries,
          profile: profile.copyWith(
              studentPilot: true, soloEndorsementDate: DateTime(2026, 10, 1)),
          now: now);
      expect(
          items.firstWhere((i) => i.kind == ReminderKind.studentSolo).validThrough,
          DateTime(2026, 12, 30));
    });
  });

  group('planReminders', () {
    test('30 and 7 days before, at 09:00, with stable ids', () {
      final plans = planReminders(
        items: [
          LapseItem(
              kind: ReminderKind.medical,
              label: 'Medical',
              validThrough: DateTime(2027, 3, 31)),
        ],
        enabled: ReminderKind.values.toSet(),
        now: now,
      );
      expect(plans.map((p) => p.at),
          [DateTime(2027, 3, 1, 9), DateTime(2027, 3, 24, 9)]);
      expect(plans.map((p) => p.id), [2030, 2007]);
      expect(plans.first.title, 'Medical: 30 days left');
      expect(plans.first.body, 'Medical is valid through 31 Mar 2027.');
    });

    test('a reminder time already past is skipped', () {
      final plans = planReminders(
        items: [
          LapseItem(
              kind: ReminderKind.flightReview,
              label: 'Flight review',
              validThrough: DateTime(2026, 10, 31)),
        ],
        enabled: ReminderKind.values.toSet(),
        now: now,
      );
      // 30 days before is 1 Oct (past); 7 days before is 24 Oct.
      expect(plans.single.leadDays, 7);
      expect(plans.single.id, 3007);
    });

    test('a kind switched off in Settings is not planned', () {
      final plans = planReminders(
        items: lapseItemsFrom(entries: entries, profile: profile, now: now),
        enabled: ReminderKind.values.toSet()..remove(ReminderKind.ifr),
        now: now,
      );
      expect(plans.map((p) => p.kind), isNot(contains(ReminderKind.ifr)));
      expect(plans.map((p) => p.kind), contains(ReminderKind.medical));
    });

    test('ids from a seeded logbook are the expected ones, in date order', () {
      final plans = planReminders(
        items: lapseItemsFrom(entries: entries, profile: profile, now: now),
        enabled: ReminderKind.values.toSet(),
        now: now,
      );
      expect(plans.map((p) => p.id), [
        4030, 5030, // 30 Nov: passengers day & night (through 30 Dec)
        4007, 5007, // 23 Dec
        3030, // 29 Jan: flight review (through 28 Feb)
        3007, // 21 Feb
        2030, // 1 Mar: medical (through 31 Mar)
        2007, // 24 Mar
        6030, // 31 Mar: IFR (through 30 Apr)
        6007, // 23 Apr
      ]);
      expect(plans.first.at, DateTime(2026, 11, 30, 9));
    });

    test('each document gets its own id range', () {
      expect(reminderId(ReminderKind.document, 30, index: 0), 7030);
      expect(reminderId(ReminderKind.document, 7, index: 2), 7207);
    });

    test('no dates, no reminders', () {
      expect(
          planReminders(
              items: const [], enabled: ReminderKind.values.toSet(), now: now),
          isEmpty);
    });
  });

  group('NotificationService.sync', () {
    final plans = planReminders(
      items: [
        LapseItem(
            kind: ReminderKind.medical,
            label: 'Medical',
            validThrough: DateTime(2027, 3, 31)),
      ],
      enabled: ReminderKind.values.toSet(),
      now: now,
    );

    test('schedules when permission is granted, cancelling old ones first',
        () async {
      final scheduled = <int>[];
      final cancelled = <int>[];
      NotificationService.permissionChecker = () async => true;
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (id) async => cancelled.add(id);

      final result =
          await NotificationService.sync(plans, previousIds: const [4030, 4007]);

      expect(scheduled, [2030, 2007]);
      expect(result.scheduled.map((r) => r.id), [2030, 2007]);
      expect(result.permissionDenied, isFalse);
      // A changed date never leaves a stale reminder behind.
      expect(cancelled, containsAll([4030, 4007, 2030, 2007]));
    });

    test('schedules nothing and says so when permission is refused',
        () async {
      final scheduled = <int>[];
      NotificationService.permissionRequester = () async => false;
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (_) async {};

      final result = await NotificationService.sync(plans, ask: true);
      expect(scheduled, isEmpty);
      expect(result.scheduled, isEmpty);
      expect(result.permissionDenied, isTrue);
    });

    test('a platform failure is not reported as a scheduled reminder',
        () async {
      NotificationService.permissionChecker = () async => true;
      NotificationService.reminderScheduler =
          (_) async => throw StateError('plugin missing');
      NotificationService.reminderCanceller = (_) async {};

      final result = await NotificationService.sync(plans);
      expect(result.scheduled, isEmpty);
      expect(result.permissionDenied, isFalse);
    });

    test('a reschedule without "ask" never shows the system prompt', () async {
      var asked = 0;
      NotificationService.permissionRequester = () async {
        asked++;
        return true;
      };
      NotificationService.permissionChecker = () async => false;
      NotificationService.reminderScheduler = (_) async {};
      NotificationService.reminderCanceller = (_) async {};
      final result = await NotificationService.sync(plans);
      expect(asked, 0);
      expect(result.scheduled, isEmpty);
      expect(result.permissionDenied, isTrue);
    });

    test('"ask" (from the Reminders screen) prompts and then schedules',
        () async {
      var asked = 0;
      final scheduled = <int>[];
      NotificationService.permissionRequester = () async {
        asked++;
        return true;
      };
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (_) async {};
      final result = await NotificationService.sync(plans, ask: true);
      expect(asked, 1);
      expect(scheduled, [2030, 2007]);
      expect(result.scheduled, hasLength(2));
    });

    test('nothing to schedule never asks for permission', () async {
      var asked = 0;
      NotificationService.permissionRequester = () async {
        asked++;
        return true;
      };
      NotificationService.reminderCanceller = (_) async {};
      final result = await NotificationService.sync(const []);
      expect(asked, 0);
      expect(result.scheduled, isEmpty);
    });
  });

  group('ReminderService', () {
    late List<int> scheduled;
    late List<int> cancelled;

    setUp(() {
      scheduled = [];
      cancelled = [];
      NotificationService.permissionChecker = () async => true;
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (id) async => cancelled.add(id);
    });

    Future<ReminderService> build({
      List<LogbookEntry> seed = const [],
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final logbook = LogbookService(store: MemoryLogbookStore(seed));
      await logbook.init();
      final settings = SettingsStore(onboardingDone: true, profile: profile);
      return ReminderService(
          settings: settings, logbook: logbook, clock: () => now);
    }

    test('reschedule follows the logbook and remembers the ids', () async {
      final svc = await build(seed: entries);
      final result = await svc.reschedule();
      expect(result.scheduled, hasLength(10));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ReminderService.kScheduledIds), hasLength(10));
    });

    test('a new flight reschedules: the previous ids are cancelled', () async {
      final svc = await build(seed: entries);
      await svc.reschedule();
      cancelled.clear();
      await svc.logbook.addEntry(entries.first.copyWith(date: DateTime(2026, 10, 12)));
      await svc.reschedule();
      expect(cancelled, containsAll([4030, 4007, 2030]));
      // Passenger currency now runs to 10 Jan 2027: 30 days before is 11 Dec.
      expect(
          svc.scheduled.firstWhere((r) => r.id == 4030).at,
          DateTime(2026, 12, 11, 9));
    });

    test('a profile change reschedules the medical reminder', () async {
      final svc = await build(seed: entries);
      await svc.settings.setProfile(profile.copyWith(age40OrOlderAtExam: false));
      await svc.reschedule();
      // Under 40: 60th month -> 31 Mar 2030.
      expect(svc.scheduled.firstWhere((r) => r.id == 2030).at,
          DateTime(2030, 3, 1, 9));
    });

    test('document expiry dates become reminders', () async {
      final svc = await build(prefs: {
        'pilot_documents': jsonEncode([
          {
            'id': 'a',
            'title': 'Renter\'s insurance',
            'category': 'Insurance',
            'filePath': '',
            'addedDate': '2026-01-01T00:00:00.000',
            'expiryDate': '2027-01-15T00:00:00.000',
          },
          {
            'id': 'b',
            'title': 'No expiry',
            'category': 'Other',
            'filePath': '',
            'addedDate': '2026-01-01T00:00:00.000',
          },
        ]),
      });
      await svc.reschedule();
      final docs =
          svc.scheduled.where((r) => r.kind == ReminderKind.document).toList();
      expect(docs.map((r) => r.id), [7030, 7007]);
      expect(docs.first.title, "Renter's insurance: 30 days left");
    });

    test('a refused permission is remembered for Settings to show', () async {
      NotificationService.permissionChecker = () async => false;
      final svc = await build(seed: entries);
      await svc.reschedule();
      expect(svc.permissionDenied, isTrue);
      expect(svc.scheduled, isEmpty);
      expect(svc.planned, isNotEmpty);
    });
  });
}
