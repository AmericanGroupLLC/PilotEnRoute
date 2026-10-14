import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/reminders/reminder_plan.dart';
import 'document_service.dart';
import 'logbook_service.dart';
import 'notification_service.dart';
import 'settings_store.dart';

/// Keeps the scheduled lapse reminders in step with the logbook, the profile
/// and the Documents expiry dates. Any change to those reschedules; the
/// switches in Settings › Reminders decide which kinds exist.
class ReminderService extends ChangeNotifier {
  ReminderService({
    required this.settings,
    required this.logbook,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SettingsStore settings;
  final LogbookService logbook;
  final DateTime Function() _clock;

  static const kScheduledIds = 'scheduled_reminder_ids_v1';

  List<PlannedReminder> _scheduled = const [];
  List<PlannedReminder> _planned = const [];
  bool _permissionDenied = false;
  Timer? _debounce;
  bool _attached = false;

  /// What is actually scheduled with the OS right now.
  List<PlannedReminder> get scheduled => _scheduled;

  /// What would be scheduled if notifications were allowed.
  List<PlannedReminder> get planned => _planned;
  bool get permissionDenied => _permissionDenied;

  void attach() {
    if (_attached) return;
    _attached = true;
    settings.addListener(_changed);
    logbook.addListener(_changed);
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (settings.onboardingDone && logbook.ready) reschedule();
    });
  }

  /// Document expiry dates from Documents (stored on the device).
  static Future<List<LapseItem>> documentItems(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(DocumentService.prefsKey);
    if (raw == null) return const [];
    final items = <LapseItem>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      var i = 0;
      for (final m in list) {
        if (m is! Map) continue;
        final d = PilotDocument.fromJson(m.cast<String, dynamic>());
        final exp = d.expiryDate;
        if (exp != null) {
          items.add(LapseItem(
            kind: ReminderKind.document,
            label: d.title,
            validThrough: DateTime(exp.year, exp.month, exp.day),
            index: i,
          ));
        }
        i++;
      }
    } catch (_) {
      return const [];
    }
    return items;
  }

  /// The plan last handed to the OS, as `id@time` pairs.
  static const kPlanSignature = 'reminder_plan_signature_v1';

  static String signatureOf(List<PlannedReminder> plans) =>
      plans.map((p) => '${p.id}@${p.at.toIso8601String()}').join(',');

  /// Recomputes and replaces the reminders. [ask] shows the system
  /// notification prompt if permission was never given; it is only set from
  /// the Reminders screen.
  ///
  /// When the plan is the same as the one last synced (every ordinary
  /// launch) nothing is sent to the notification system at all, unless
  /// [ask] or [force] is set. Opening the app must never wait on the OS
  /// notification service: on the iOS 27 simulator a launch-time
  /// UNUserNotificationCenter call was seen to block the main thread for
  /// good.
  Future<ReminderSyncResult> reschedule({
    bool ask = false,
    bool force = false,
  }) async {
    final now = _clock();
    final items = [
      ...lapseItemsFrom(
        entries: logbook.entries,
        profile: settings.profile,
        now: now,
      ),
      ...await documentItems(now),
    ];
    final plans = planReminders(
      items: items,
      enabled: settings.reminderKinds,
      now: now,
    );
    final prefs = await SharedPreferences.getInstance();
    final previous = (prefs.getStringList(kScheduledIds) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final signature = signatureOf(plans);
    if (!ask && !force && prefs.getString(kPlanSignature) == signature) {
      _planned = plans;
      _scheduled = [for (final p in plans) if (previous.contains(p.id)) p];
      _permissionDenied = plans.isNotEmpty && _scheduled.isEmpty;
      notifyListeners();
      return ReminderSyncResult(_scheduled,
          permissionDenied: _permissionDenied);
    }
    final result =
        await NotificationService.sync(plans, previousIds: previous, ask: ask);
    await prefs.setStringList(
        kScheduledIds, result.scheduled.map((r) => '${r.id}').toList());
    await prefs.setString(kPlanSignature, signature);
    _planned = plans;
    _scheduled = result.scheduled;
    _permissionDenied = result.permissionDenied;
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_attached) {
      settings.removeListener(_changed);
      logbook.removeListener(_changed);
    }
    super.dispose();
  }
}
