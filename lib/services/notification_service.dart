import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders/reminder_plan.dart';

/// Local lapse reminders: 30 and 7 days before each date the legality engine
/// works out, and before document expiries. Nothing is pushed from a server;
/// these are scheduled on the device.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'lapse_reminders';
  static const String channelName = 'Lapse reminders';
  static const String channelDescription =
      'Before your medical, flight review, currency or a document lapses';

  /// Sets the plugin up. Deliberately does **not** ask for permission.
  ///
  /// This is awaited by `main()` before `runApp()`. With the three
  /// `request*Permission` flags set, `_plugin.initialize` calls iOS's
  /// `requestAuthorization` and does not return until the user answers the
  /// system alert — so on a clean install the app painted nothing at all.
  /// Verified earlier on a freshly erased iPhone 17 Pro Max simulator.
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    ));
  }

  /// Asks for notification permission. iOS shows the system alert only for
  /// the first request and afterwards answers from the stored decision.
  static Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Whether alerts may be posted right now, without asking. Never shows the
  /// system prompt.
  static Future<bool> currentPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return (await ios.checkPermissions())?.isEnabled ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Seams so tests can observe scheduling without the platform plugin.
  @visibleForTesting
  static Future<bool> Function() permissionRequester = requestPermissions;
  @visibleForTesting
  static Future<bool> Function() permissionChecker = currentPermission;
  @visibleForTesting
  static Future<void> Function(PlannedReminder reminder) reminderScheduler =
      _schedule;
  @visibleForTesting
  static Future<void> Function(int id) reminderCanceller =
      (id) => _plugin.cancel(id);

  /// Replaces every reminder this app scheduled before ([previousIds]) with
  /// [plans]. Shows the system permission prompt only when [ask] is true —
  /// i.e. when the pilot asked for reminders on the Reminders screen — never
  /// as a side effect of logging a flight or finishing onboarding. Returns
  /// what was really scheduled, so the UI never lists a reminder that does
  /// not exist.
  static Future<ReminderSyncResult> sync(
    List<PlannedReminder> plans, {
    Iterable<int> previousIds = const [],
    bool ask = false,
  }) async {
    final cancel = <int>{
      ...previousIds,
      for (final p in plans) p.id,
    };
    for (final id in cancel) {
      try {
        await reminderCanceller(id);
      } catch (e) {
        debugPrint('Cancelling reminder $id failed: $e');
      }
    }
    if (plans.isEmpty) return const ReminderSyncResult([]);

    bool granted;
    try {
      granted = ask ? await permissionRequester() : await permissionChecker();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      granted = false;
    }
    if (!granted) {
      return const ReminderSyncResult([], permissionDenied: true);
    }

    final scheduled = <PlannedReminder>[];
    for (final plan in plans) {
      try {
        await reminderScheduler(plan);
        scheduled.add(plan);
      } catch (e) {
        debugPrint('Scheduling reminder ${plan.id} failed: $e');
      }
    }
    return ReminderSyncResult(scheduled);
  }

  static Future<void> _schedule(PlannedReminder r) async {
    await _plugin.zonedSchedule(
      r.id,
      r.title,
      r.body,
      tz.TZDateTime.from(r.at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

/// What [NotificationService.sync] actually did.
class ReminderSyncResult {
  const ReminderSyncResult(this.scheduled, {this.permissionDenied = false});

  final List<PlannedReminder> scheduled;
  final bool permissionDenied;
}
