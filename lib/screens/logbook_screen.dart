import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/logbook/logbook_query.dart';
import '../services/logbook_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../widgets/ad_banner_widget.dart';
import 'logbook_entry_screen.dart';

/// The logbook: a ruled ledger grouped by month, with search, filters,
/// window totals and export (PDF, Share PDF, Copy as CSV).
class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key, this.clock});

  final DateTime Function()? clock;

  /// The in-list banner goes after this many rows.
  static const adAfterRow = 5;

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  LogbookQuery _query = LogbookQuery.all;
  bool _busy = false;

  /// Rows swiped away but not yet gone from the store. A dismissed
  /// Dismissible must leave the tree in the same frame.
  final Set<int> _pendingDeletes = {};

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LogbookService>().init();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEntry({LogbookEntry? existing}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogbookEntryScreen(existing: existing, clock: widget.clock),
      fullscreenDialog: existing == null,
    ));
  }

  Future<void> _export(String action, LogbookService svc) async {
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'csv') {
      await Clipboard.setData(ClipboardData(text: svc.toCsv()));
      messenger.showSnackBar(SnackBar(
          content: Text('Copied ${svc.entries.length} '
              'flight${svc.entries.length == 1 ? '' : 's'} as CSV')));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await svc.buildLogbookPdf();
      if (action == 'share') {
        await Printing.sharePdf(bytes: bytes, filename: 'pilot_logbook.pdf');
      } else {
        await Printing.layoutPdf(
            onLayout: (_) async => bytes, name: 'pilot_logbook.pdf');
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not export the logbook PDF: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(LogbookEntry e, LogbookService svc) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pendingDeletes.add(e.id!));
    await svc.deleteEntry(e.id!);
    if (mounted) setState(() => _pendingDeletes.remove(e.id));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Deleted ${e.from}→${e.to} on ${dayMonthYear(e.date)}'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => svc.restoreEntry(e),
      ),
    ));
  }

  Future<void> _filters() async {
    final q = await showModalBottomSheet<LogbookQuery>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _query),
    );
    if (q != null) setState(() => _query = q.copyWith(text: _search.text));
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LogbookService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logbook'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onSelected: (a) => _export(a, svc),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Print or save PDF'))),
              PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Share PDF'))),
              PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Copy as CSV'))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Flights'), Tab(text: 'Totals')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntry(),
        icon: const Icon(Icons.add),
        label: const Text('Log flight',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _flights(context, svc),
          _totals(context, svc),
        ],
      ),
    );
  }

  Widget _flights(BuildContext context, LogbookService svc) {
    final scheme = Theme.of(context).colorScheme;
    if (svc.isLoading && !svc.ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = filterEntries(
        svc.entries.where((e) => !_pendingDeletes.contains(e.id)).toList(),
        _query);
    final groups = groupByMonth(filtered);
    final rows = <Widget>[];
    var row = 0;
    for (final g in groups) {
      rows.add(_monthHeader(context, g));
      for (final e in g.entries) {
        rows.add(_ledgerRow(context, e, svc));
        row++;
        if (row == LogbookScreen.adAfterRow) {
          rows.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: AdBannerWidget(),
          ));
        }
      }
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('logbook-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Airport, tail, type, remarks',
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = _query.copyWith(text: '');
                            }),
                          ),
                  ),
                  onChanged: (t) =>
                      setState(() => _query = _query.copyWith(text: t)),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _query.filterCount > 0,
                label: Text('${_query.filterCount}'),
                child: IconButton.outlined(
                  tooltip: 'Filters',
                  icon: const Icon(Icons.filter_list),
                  onPressed: _filters,
                ),
              ),
            ],
          ),
        ),
        if (svc.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NoticeLine(icon: Icons.error_outline, text: svc.error!),
          ),
        Expanded(
          child: svc.entries.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    NoticeLine(
                      icon: Icons.menu_book_outlined,
                      text: 'No flights logged yet. Tap "Log flight" to add '
                          'your recent flights; the Go Card works out your '
                          'currency from them.',
                    ),
                  ],
                )
              : filtered.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        NoticeLine(
                          icon: Icons.search_off,
                          text: 'No flights match. ${svc.entries.length} in '
                              'the logbook.',
                          action: TextButton(
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = LogbookQuery.all;
                            }),
                            child: const Text('Clear search and filters'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Text(
                            '${filtered.length} of ${svc.entries.length} '
                            'flights · swipe left to delete',
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                        ...rows,
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _monthHeader(BuildContext context, MonthGroup g) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(monthYear(g.month).toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
          ),
          Flexible(
            child: Text('${g.entries.length} · ${g.hours.toStringAsFixed(1)} h',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(BuildContext context, LogbookEntry e, LogbookService svc) {
    final scheme = Theme.of(context).colorScheme;
    const mono = TextStyle(fontFamily: AppFonts.mono, fontSize: 13);
    final flags = [
      if (e.isNight) 'N',
      if (e.isIfr) 'IFR',
      if (e.flightReview) 'FR',
      if (e.ipc) 'IPC',
      if (e.practicalTest) 'PT',
    ];
    return Dismissible(
      key: ValueKey('entry-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: scheme.onError),
            const SizedBox(width: 6),
            Text('Delete', style: TextStyle(color: scheme.onError)),
          ],
        ),
      ),
      onDismissed: (_) => _delete(e, svc),
      child: InkWell(
        onTap: () => _openEntry(existing: e),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                  '${e.date.day.toString().padLeft(2, '0')}\n'
                  '${monthYear(e.date).substring(0, 3).toUpperCase()}',
                  style: mono.copyWith(height: 1.15),
                ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.from.isEmpty ? '----' : e.from} → '
                        '${e.to.isEmpty ? '----' : e.to}',
                        style: mono.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (e.aircraftType.isNotEmpty) e.aircraftType,
                        if (e.tailNumber.isNotEmpty) e.tailNumber,
                        e.categoryClass.isEmpty ? 'no class' : e.categoryClass,
                        if (e.tailwheel) 'TW',
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    if (flags.isNotEmpty || e.remarks.isNotEmpty)
                      Text(
                        [flags.join(' '), e.remarks]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(e.totalTime.toStringAsFixed(1),
                      style: mono.copyWith(fontWeight: FontWeight.w700)),
                  Text('${e.totalLandings} ldg', style: mono.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totals(BuildContext context, LogbookService svc) {
    final now = _now();
    final windows = <(String, int?)>[
      ('30 days', 30),
      ('90 days', 90),
      ('365 days', 365),
      ('All time', null),
    ];
    final cols = [
      for (final w in windows) totalsWithin(svc.entries, now: now, days: w.$2)
    ];
    String h(double v) => v.toStringAsFixed(1);
    final rows = <(String, String Function(LogbookTotals))>[
      ('Flights', (t) => '${t.totalFlights}'),
      ('Total', (t) => h(t.totalTime)),
      ('PIC', (t) => h(t.picTime)),
      ('SIC', (t) => h(t.sicTime)),
      ('Dual rcvd', (t) => h(t.dualReceived)),
      ('Solo', (t) => h(t.soloTime)),
      ('XC', (t) => h(t.crossCountry)),
      ('Night', (t) => h(t.night)),
      ('Actual inst', (t) => h(t.actualInstrument)),
      ('Sim inst', (t) => h(t.simulatedInstrument)),
      ('Approaches', (t) => '${t.approaches}'),
      ('Day T/O', (t) => '${t.dayTakeoffs}'),
      ('Day ldg', (t) => '${t.dayLandings}'),
      ('Night T/O', (t) => '${t.nightTakeoffs}'),
      ('Night ldg', (t) => '${t.nightLandings}'),
    ];
    const mono = TextStyle(fontFamily: AppFonts.mono, fontSize: 13);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Totals', subtitle: 'Hours and counts by window'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.5)},
          border: TableBorder(
              horizontalInside: BorderSide(color: scheme.outlineVariant)),
          children: [
            TableRow(children: [
              const SizedBox(),
              for (final w in windows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(w.$1,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            for (final r in rows)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(r.$1),
                ),
                for (final t in cols)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(r.$2(t), textAlign: TextAlign.right, style: mono),
                  ),
              ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '"30 days" is today and the 29 days before it.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final LogbookQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LogbookQuery q = widget.initial;

  Future<void> _date(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? q.from : q.to) ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d == null) return;
    setState(() => q = from ? q.copyWith(from: d) : q.copyWith(to: d));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Filters'),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _date(true),
                  child: Text(q.from == null ? 'From date' : dayMonthYear(q.from!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _date(false),
                  child: Text(q.to == null ? 'To date' : dayMonthYear(q.to!)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final p in ['', ...CategoryClass.presets])
                ChoiceChip(
                  label: Text(p.isEmpty ? 'Any class' : p),
                  selected: q.categoryClass == p,
                  onSelected: (_) =>
                      setState(() => q = q.copyWith(categoryClass: p)),
                ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              FilterChip(
                  label: const Text('Night'),
                  selected: q.night,
                  onSelected: (v) => setState(() => q = q.copyWith(night: v))),
              FilterChip(
                  label: const Text('IFR'),
                  selected: q.ifr,
                  onSelected: (v) => setState(() => q = q.copyWith(ifr: v))),
              FilterChip(
                  label: const Text('Flight review'),
                  selected: q.flightReview,
                  onSelected: (v) =>
                      setState(() => q = q.copyWith(flightReview: v))),
              FilterChip(
                  label: const Text('IPC'),
                  selected: q.ipc,
                  onSelected: (v) => setState(() => q = q.copyWith(ipc: v))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(LogbookQuery(text: q.text)),
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(q),
                child: const Text('Apply'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
