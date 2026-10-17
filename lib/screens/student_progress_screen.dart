import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/private_pilot_progress.dart';
import '../services/logbook_service.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// A student's progress toward the 61.109(a) private pilot (airplane
/// single-engine) aeronautical experience, from their own logbook. Items the
/// logbook cannot show are listed as "not tracked", never as met.
class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LogbookService>();
    final now = (clock ?? DateTime.now)();
    final p = privatePilotProgress(entries: svc.entries, now: now);
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Private pilot progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionHeader('14 CFR 61.109(a)',
              subtitle: 'Airplane single-engine · ${p.metCount} of '
                  '${p.tracked.length} tracked items met'),
          if (svc.entries.isEmpty)
            const NoticeLine(
              icon: Icons.menu_book_outlined,
              text: 'No flights logged yet. Log your lessons and solo flights '
                  'and this shows what is left.',
            ),
          for (final item in p.items) _row(context, item),
          const SizedBox(height: 12),
          if (p.mixedEntries > 0)
            NoticeLine(
              key: const Key('progress-mixed'),
              icon: Icons.call_split,
              text: '${p.mixedEntries} '
                  'entr${p.mixedEntries == 1 ? 'y logs' : 'ies log'} both dual '
                  'and solo time. Their cross-country, night and instrument '
                  'time and night takeoffs and landings cannot be split, so '
                  'they are not counted above. Log '
                  'dual and solo legs as separate entries.',
            ),
          if (p.unclassedEntries > 0)
            NoticeLine(
              icon: Icons.label_off_outlined,
              text: '${p.unclassedEntries} '
                  'entr${p.unclassedEntries == 1 ? 'y has' : 'ies have'} no '
                  'category/class, so only the 40 h of flight time counts '
                  'them. Edit them to ASEL or ASES.',
            ),
          const SizedBox(height: 6),
          Text(
            'Practical test preparation counts all single-engine dual time '
            'since the first day of the second calendar month before this '
            'one, i.e. a test this month. Your instructor decides which of '
            'it was test preparation.',
            style: small,
          ),
          const SizedBox(height: 6),
          Text(
            'Not handled here: the 61.109(k) and 61.110 exceptions, part 141 '
            'courses, simulator credit, and the endorsements you need. Meeting '
            'every item does not by itself make you eligible for the test. '
            'Check with your instructor.',
            style: small,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ProgressItem item) {
    final scheme = Theme.of(context).colorScheme;
    final look = !item.tracked
        ? const StatusLook('CHECK', Icons.help_outline, Tone.neutral)
        : item.met
            ? const StatusLook('MET', Icons.check_circle, Tone.go)
            : const StatusLook('TO DO', Icons.radio_button_unchecked,
                Tone.caution);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text(
                      item.tracked
                          ? '${item.cite} · ${item.progressText}'
                          : '${item.cite} · The logbook does not record '
                              'this. Confirm it with your instructor.',
                      style: TextStyle(
                          fontFamily: item.tracked ? AppFonts.mono : null,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(look),
            ],
          ),
          if (item.tracked) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: Rbf.corners,
              child: LinearProgressIndicator(
                value: item.fraction,
                minHeight: 5,
                color: toneColor(context, look.tone),
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
