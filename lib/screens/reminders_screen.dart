import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/reminders/reminder_plan.dart';
import '../services/reminder_service.dart';
import '../services/settings_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Which lapse reminders exist, and the ones actually scheduled. Reminders
/// fire at 09:00 local, 30 and 7 days before each date.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Show the real state on open, without prompting.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mounted ? _refresh(ask: false) : null);
  }

  Future<void> _refresh({bool ask = true}) async {
    final svc = context.read<ReminderService?>();
    if (svc == null) return;
    setState(() => _busy = true);
    await svc.reschedule(ask: ask);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final svc = context.watch<ReminderService?>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Remind me about',
              subtitle: '30 and 7 days before each lapse date, at 09:00'),
          for (final k in ReminderKind.values)
            SwitchListTile(
              key: Key('reminder-${k.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(k.label),
              value: s.reminderKinds.contains(k),
              onChanged: (v) async {
                await s.setReminderKind(k, v);
                await _refresh();
              },
            ),
          const SizedBox(height: 16),
          SectionHeader('Scheduled',
              trailing: IconButton(
                tooltip: 'Reschedule now',
                onPressed: _busy || svc == null ? null : _refresh,
                icon: const Icon(Icons.refresh),
              )),
          if (svc == null)
            const NoticeLine(
                icon: Icons.info_outline, text: 'Reminders are not available.')
          else if (svc.permissionDenied)
            NoticeLine(
              icon: Icons.notifications_off_outlined,
              text: 'Notifications are not allowed for PilotEnRoute yet, so '
                  'no reminder is scheduled. If you turned them off before, '
                  'turn them back on in the system Settings app.',
              action: FilledButton(
                key: const Key('allow-notifications'),
                onPressed: _busy ? null : _refresh,
                child: const Text('Allow notifications'),
              ),
            )
          else if (svc.scheduled.isEmpty)
            const NoticeLine(
              icon: Icons.event_available,
              text: 'Nothing scheduled. Reminders appear once a date is known '
                  '(medical, flight review, currency, a document expiry) and '
                  'is more than 7 days away.',
            )
          else
            for (final r in svc.scheduled)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: scheme.outlineVariant))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(dayMonthYear(r.at),
                          style: const TextStyle(
                              fontFamily: AppFonts.mono, fontSize: 13)),
                    ),
                    Expanded(child: Text(r.title)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
