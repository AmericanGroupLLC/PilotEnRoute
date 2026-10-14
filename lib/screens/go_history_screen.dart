import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/minimums/go_check.dart';
import '../core/minimums/go_record.dart';
import '../services/logbook_service.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Every Go Card check, saved on the device with the raw METAR/TAF and the
/// result. Search by airport, filter by result.
class GoHistoryScreen extends StatefulWidget {
  const GoHistoryScreen({super.key});

  @override
  State<GoHistoryScreen> createState() => _GoHistoryScreenState();
}

class _GoHistoryScreenState extends State<GoHistoryScreen> {
  final _search = TextEditingController();
  GoVerdict? _verdict;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _when(DateTime d) =>
      '${dayMonthYear(d)} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LogbookService>();
    final list =
        filterChecks(svc.checks, airport: _search.text, verdict: _verdict);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Check history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              key: const Key('history-search'),
              controller: _search,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Airport',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _verdict == null,
                    onSelected: (_) => setState(() => _verdict = null),
                  ),
                ),
                for (final v in GoVerdict.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(lookForVerdict(v).label),
                      selected: _verdict == v,
                      onSelected: (_) => setState(() => _verdict = v),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    NoticeLine(
                      icon: Icons.history,
                      text: svc.checks.isEmpty
                          ? 'No checks yet. Each Go Card check is saved here.'
                          : 'No checks match.',
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final r = list[i];
                      return Dismissible(
                        key: ValueKey('check-${r.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(color: scheme.error),
                        onDismissed: (_) => svc.deleteCheck(r.id!),
                        child: ExpansionTile(
                          title: Text(
                            '${r.departure}${r.destination.isEmpty || r.destination == r.departure ? '' : ' → ${r.destination}'}',
                            style: const TextStyle(
                                fontFamily: AppFonts.mono,
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Checked ${_when(r.createdAt)} · for '
                                  '${_when(r.plannedAt)}'),
                              Text(r.headline,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: StatusTag(lookForVerdict(r.verdict),
                              dense: true),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: [
                            if (r.metarRaw.isNotEmpty) MonoBlock(r.metarRaw),
                            if (r.tafRaw.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              MonoBlock(r.tafRaw),
                            ],
                            const SizedBox(height: 6),
                            Text(r.detail,
                                style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
