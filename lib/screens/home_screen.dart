import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/legality/legality_engine.dart';
import '../core/legality/private_pilot_progress.dart';
import '../services/logbook_service.dart';
import '../services/practice_store.dart';
import '../services/settings_store.dart';
import '../ui/sky_scene.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'app_shell.dart';
import 'logbook_entry_screen.dart';
import 'student_progress_screen.dart';

/// Home: today at a glance. Everything on it comes from the pilot's own
/// profile, logbook and practice results; nothing is sample content. No ad
/// (the Go Card summary is on it).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.clock});

  final DateTime Function()? clock;

  DateTime _now() => (clock ?? DateTime.now)();

  /// Legal today for a day flight without passengers in the home
  /// category/class. Weather and minimums are only checked on the Go Card.
  static LegalityReport todayReport({
    required List<LogbookEntry> entries,
    required SettingsStore settings,
    required DateTime now,
  }) =>
      const LegalityEngine().evaluate(
        entries: entries,
        profile: settings.profile,
        flight: PlannedFlight(
            date: now, categoryClass: settings.profile.homeCategoryClass),
      );

  void _openTab(BuildContext context, int i) =>
      context.findAncestorStateOfType<AppShellState>()?.select(i);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final logbook = context.watch<LogbookService>();
    final practice = context.watch<PracticeStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = _now();
    final report =
        todayReport(entries: logbook.entries, settings: settings, now: now);
    final notLegal = report.notLegalLine;
    final airport = settings.homeAirport.isEmpty ? '' : ' · ${settings.homeAirport}';
    final last = _latest(logbook.entries);
    final student = settings.profile.studentPilot;
    final progress = student
        ? privatePilotProgress(entries: logbook.entries, now: now)
        : null;
    final readiness = practice.readiness;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: PageTitle('Ready for takeoff?',
            subtitle: 'Today at a glance · ${dayMonthYear(now)}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerLowest,
                side: BorderSide(color: scheme.outlineVariant),
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.settings_outlined, size: 22),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SkyCard(
            padding: EdgeInsets.zero,
            radius: Sky.cornersL,
            child: Stack(children: [
              const SkyScene(height: 150),
              Positioned(
                left: 16,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest.withValues(alpha: .92),
                    borderRadius: Sky.cornersM,
                  ),
                  child: Text('Small steps today.\nBig skies tomorrow.',
                      style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.25,
                          color: scheme.onSurface)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Before you fly',
              subtitle: 'Day, no passengers, your home class. Weather and '
                  'minimums are checked on the Go Card.'),
          NavRowCard(
            key: const Key('home-go-card'),
            icon: Icons.flight_takeoff_rounded,
            title: 'Go Card$airport',
            subtitle: notLegal ?? 'Legal to fly today. Check the weather next.',
            trailing: StatusTag(
                notLegal == null
                    ? const StatusLook('LEGAL', Icons.check_circle, Tone.go)
                    : lookForVerdictNotLegal,
                dense: true),
            onTap: () => Navigator.of(context).pushNamed('/go'),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            NavRowCard(
              key: const Key('home-student-progress'),
              icon: Icons.school_outlined,
              title: 'Private pilot progress',
              subtitle: '61.109(a) · ${progress.metCount} of '
                  '${progress.items.where((i) => i.tracked).length} '
                  'tracked items met',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StudentProgressScreen(clock: clock))),
            ),
          ],
          const SizedBox(height: 18),
          const SectionHeader('Your next steps'),
          NavRowCard(
            key: const Key('home-knowledge-test'),
            icon: Icons.quiz_outlined,
            title: 'Knowledge test practice',
            subtitle: readiness == null
                ? 'FAA sample questions, each answer shown in FAA text'
                : 'First try: ${(readiness * 100).round()}% of '
                    '${practice.questionsTried} questions · goal '
                    '${PracticeStore.goal}',
            onTap: () => _openTab(context, AppShell.practiceTab),
          ),
          const SizedBox(height: 10),
          NavRowCard(
            key: const Key('home-learn'),
            icon: Icons.menu_book_outlined,
            title: 'Ground school',
            subtitle: 'FAA handbooks, the six instruments, airport signs',
            onTap: () => _openTab(context, AppShell.learnTab),
          ),
          const SizedBox(height: 10),
          NavRowCard(
            key: const Key('home-log-flight'),
            icon: Icons.edit_note_rounded,
            title: 'Log a flight',
            subtitle: last == null
                ? 'No flights logged yet'
                : 'Last logged: ${_route(last)} · '
                    '${dayMonth(last.date, reference: now)}',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LogbookEntryScreen(clock: clock))),
          ),
        ],
      ),
    );
  }

  static const lookForVerdictNotLegal =
      StatusLook('NOT LEGAL', Icons.block, Tone.stop);

  static LogbookEntry? _latest(List<LogbookEntry> entries) {
    LogbookEntry? best;
    for (final e in entries) {
      if (best == null || e.date.isAfter(best.date)) best = e;
    }
    return best;
  }

  static String _route(LogbookEntry e) {
    if (e.from.isEmpty && e.to.isEmpty) return e.aircraftType;
    if (e.from == e.to || e.to.isEmpty) return e.from;
    return '${e.from} → ${e.to}';
  }
}
