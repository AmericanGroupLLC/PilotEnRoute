/// Medical and flight-review expiry reminders.
///
/// The store promises "a reminder before your medical expires", but the
/// scheduling methods were never called. Saving the Profile now schedules
/// them, and the confirmation names only reminders that really exist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/profile_screen.dart';
import 'package:pilot_enroute/services/notification_service.dart';

void main() {
  final now = DateTime(2026, 10, 11, 12);

  tearDown(() {
    NotificationService.permissionRequester =
        NotificationService.requestPermissions;
    NotificationService.clock = DateTime.now;
  });

  group('reminderTimeBefore', () {
    test('a far-off expiry is reminded 90 days ahead at 09:00', () {
      final at = NotificationService.reminderTimeBefore(
          DateTime(2027, 6, 30), now: now);
      expect(at, DateTime(2027, 4, 1, 9));
    });

    test('inside 90 days it falls back to 30, then 7, then 1 day', () {
      expect(
        NotificationService.reminderTimeBefore(DateTime(2026, 12, 1),
            now: now),
        DateTime(2026, 11, 1, 9),
      );
      expect(
        NotificationService.reminderTimeBefore(DateTime(2026, 10, 25),
            now: now),
        DateTime(2026, 10, 18, 9),
      );
      expect(
        NotificationService.reminderTimeBefore(DateTime(2026, 10, 14),
            now: now),
        DateTime(2026, 10, 13, 9),
      );
    });

    test('an expiry that is today or past gets no reminder', () {
      expect(
          NotificationService.reminderTimeBefore(DateTime(2026, 10, 12),
              now: now),
          isNull);
      expect(
          NotificationService.reminderTimeBefore(DateTime(2026, 1, 1),
              now: now),
          isNull);
    });
  });

  group('planExpiryReminders', () {
    test('both dates produce one reminder each, with the real day count', () {
      final plans = NotificationService.planExpiryReminders(
        medicalExpiry: DateTime(2027, 6, 30),
        flightReviewDue: DateTime(2026, 12, 1),
        now: now,
      );
      expect(plans.map((p) => p.id), [
        NotificationService.medicalReminderId,
        NotificationService.flightReviewReminderId,
      ]);
      expect(plans[0].body, contains('90 days'));
      expect(plans[1].body, contains('30 days'));
    });

    test('no dates, no reminders', () {
      expect(NotificationService.planExpiryReminders(now: now), isEmpty);
    });
  });

  group('syncExpiryReminders', () {
    test('schedules when permission is granted', () async {
      final scheduled = <int>[];
      final cancelled = <int>[];
      NotificationService.clock = () => now;
      NotificationService.permissionRequester = () async => true;
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (id) async => cancelled.add(id);

      final result = await NotificationService.syncExpiryReminders(
        medicalExpiry: DateTime(2027, 6, 30),
      );

      expect(scheduled, [NotificationService.medicalReminderId]);
      expect(result.scheduled.single.id, NotificationService.medicalReminderId);
      expect(result.permissionDenied, isFalse);
      // Old reminders are cleared first so a changed date never leaves a
      // stale one behind.
      expect(cancelled, containsAll([
        NotificationService.medicalReminderId,
        NotificationService.flightReviewReminderId,
      ]));
    });

    test('schedules nothing and says so when permission is refused',
        () async {
      final scheduled = <int>[];
      NotificationService.clock = () => now;
      NotificationService.permissionRequester = () async => false;
      NotificationService.reminderScheduler = (r) async => scheduled.add(r.id);
      NotificationService.reminderCanceller = (_) async {};

      final result = await NotificationService.syncExpiryReminders(
        medicalExpiry: DateTime(2027, 6, 30),
      );

      expect(scheduled, isEmpty);
      expect(result.scheduled, isEmpty);
      expect(result.permissionDenied, isTrue);
      expect(profileSavedMessage(result), contains('no expiry reminder'));
    });

    test('a platform failure is not reported as a scheduled reminder',
        () async {
      NotificationService.clock = () => now;
      NotificationService.permissionRequester = () async => true;
      NotificationService.reminderScheduler =
          (_) async => throw StateError('plugin missing');
      NotificationService.reminderCanceller = (_) async {};

      final result = await NotificationService.syncExpiryReminders(
        flightReviewDue: DateTime(2027, 6, 30),
      );

      expect(result.scheduled, isEmpty);
      expect(profileSavedMessage(result), 'Profile saved');
    });
  });

  test('the save message names the reminder date that was set', () {
    final result = ExpiryReminderResult([
      ExpiryReminder(
        id: NotificationService.medicalReminderId,
        at: DateTime(2027, 4, 1, 9),
        channelId: 'medical_reminders',
        title: 't',
        body: 'b',
      ),
    ]);
    expect(profileSavedMessage(result),
        'Profile saved. Set medical reminder on 4/1/2027.');
  });
}
