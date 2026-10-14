/// Which lapse reminders should exist: 30 and 7 days before every date the
/// legality engine works out (medical, flight review, the three 61.57 items,
/// a student's solo endorsement) and every document expiry. Pure Dart, so the
/// ids and dates are tested without the notification plugin.
library;

import '../legality/calendar.dart';
import '../legality/date_text.dart';
import '../legality/legality_engine.dart';
import '../legality/pilot_profile.dart';
import '../logbook/logbook_entry.dart';

enum ReminderKind {
  medical('Medical'),
  flightReview('Flight review'),
  dayPassengers('Passenger currency'),
  nightPassengers('Night passenger currency'),
  ifr('IFR currency'),
  studentSolo('Solo endorsement'),
  document('Document expiry');

  const ReminderKind(this.label);
  final String label;

  static ReminderKind? fromName(String n) {
    for (final k in values) {
      if (k.name == n) return k;
    }
    return null;
  }
}

/// Days before the lapse date a reminder fires.
const List<int> reminderLeadDays = [30, 7];

class LapseItem {
  final ReminderKind kind;
  final String label;

  /// Last valid day.
  final DateTime validThrough;

  /// Document position, so each document gets its own id range.
  final int index;

  const LapseItem({
    required this.kind,
    required this.label,
    required this.validThrough,
    this.index = 0,
  });
}

class PlannedReminder {
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final ReminderKind kind;
  final int leadDays;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
    required this.leadDays,
  });
}

/// Stable notification id: re-scheduling with the same id replaces the old
/// reminder instead of stacking a second one.
int reminderId(ReminderKind kind, int leadDays, {int index = 0}) {
  final base = switch (kind) {
    ReminderKind.medical => 2000,
    ReminderKind.flightReview => 3000,
    ReminderKind.dayPassengers => 4000,
    ReminderKind.nightPassengers => 5000,
    ReminderKind.ifr => 6000,
    ReminderKind.studentSolo => 6500,
    ReminderKind.document => 7000 + index * 100,
  };
  return base + leadDays;
}

/// The lapse dates worth reminding about, from the engine. Uses a generic
/// flight today in the pilot's home category/class with passengers at night
/// (so all three 61.57 items are computed); IFR only for instrument-rated
/// pilots. Items already lapsed get no reminder — the Go Card shows them.
List<LapseItem> lapseItemsFrom({
  required List<LogbookEntry> entries,
  required PilotProfile profile,
  required DateTime now,
}) {
  final report = const LegalityEngine().evaluate(
    entries: entries,
    profile: profile,
    flight: PlannedFlight(
      date: dateOnly(now),
      categoryClass: profile.homeCategoryClass,
      tailwheel: profile.homeTailwheel,
      passengers: true,
      night: true,
      ifr: profile.instrumentRated,
    ),
  );
  final items = <LapseItem>[];
  void add(RuleId id, ReminderKind kind) {
    final matches = report.rules.where((r) => r.id == id);
    if (matches.isEmpty) return;
    final r = matches.first;
    if (r.state != RuleState.valid || r.validThrough == null) return;
    items.add(LapseItem(
      kind: kind,
      label: kind == ReminderKind.dayPassengers ||
              kind == ReminderKind.nightPassengers
          ? '${kind.label} (${profile.homeCategoryClass})'
          : kind.label,
      validThrough: r.validThrough!,
    ));
  }

  add(RuleId.medical, ReminderKind.medical);
  add(RuleId.flightReview, ReminderKind.flightReview);
  add(RuleId.dayPassengers, ReminderKind.dayPassengers);
  add(RuleId.nightPassengers, ReminderKind.nightPassengers);
  if (profile.instrumentRated) add(RuleId.ifr, ReminderKind.ifr);
  if (profile.studentPilot) add(RuleId.studentSolo, ReminderKind.studentSolo);
  return items;
}

/// Reminders at 09:00 local, [reminderLeadDays] before each item's last
/// valid day, skipping any that are already in the past and any kind the
/// pilot switched off.
List<PlannedReminder> planReminders({
  required List<LapseItem> items,
  required Set<ReminderKind> enabled,
  required DateTime now,
}) {
  final plans = <PlannedReminder>[];
  for (final item in items) {
    if (!enabled.contains(item.kind)) continue;
    for (final lead in reminderLeadDays) {
      final day = addDays(item.validThrough, -lead);
      final at = DateTime(day.year, day.month, day.day, 9);
      if (!at.isAfter(now)) continue;
      plans.add(PlannedReminder(
        id: reminderId(item.kind, lead, index: item.index),
        at: at,
        kind: item.kind,
        leadDays: lead,
        title: '${item.label}: $lead days left',
        body: '${item.label} is valid through '
            '${dayMonthYear(item.validThrough)}.',
      ));
    }
  }
  plans.sort((a, b) => a.at.compareTo(b.at));
  return plans;
}
