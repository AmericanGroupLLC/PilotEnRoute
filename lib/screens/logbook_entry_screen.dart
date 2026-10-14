import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/logbook/entry_validation.dart';
import '../services/logbook_service.dart';
import '../services/settings_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Full-screen logbook entry: everything 14 CFR 61.57 and 61.56 count, so the
/// Go Card can work currency out from what is logged here.
///
/// New entry, edit ([existing]) or pre-filled from the Go Card ([prefill]).
/// No ad is shown on this screen.
class LogbookEntryScreen extends StatefulWidget {
  const LogbookEntryScreen({super.key, this.existing, this.prefill, this.clock});

  final LogbookEntry? existing;
  final LogbookEntry? prefill;
  final DateTime Function()? clock;

  @override
  State<LogbookEntryScreen> createState() => LogbookEntryScreenState();
}

class LogbookEntryScreenState extends State<LogbookEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  Map<String, String> _cross = {};

  late DateTime _date;
  String _categoryClass = '';
  bool _otherClass = false;
  bool _tailwheel = false;
  bool _holding = false;
  bool _tracking = false;
  bool _flightReview = false;
  bool _ipc = false;
  bool _practicalTest = false;
  bool _ifr = false;
  bool _nightFlight = false;
  bool _saving = false;

  static const _hourFields = [
    'total', 'pic', 'sic', 'dual', 'solo', 'cfi', 'xc', 'night', 'actual', 'sim',
  ];
  static const _countFields = [
    'dayTo', 'dayLdg', 'dayFullStop', 'nightTo', 'nightLdg', 'approaches',
  ];

  TextEditingController c(String k) => _c.putIfAbsent(k, TextEditingController.new);

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = (widget.clock ?? DateTime.now)();
    final e = widget.existing ?? widget.prefill;
    _date = e?.date ?? DateTime(now.year, now.month, now.day);
    if (e != null) {
      _fill(e, includeTimes: widget.existing != null);
    } else {
      final s = context.read<SettingsStore>();
      _categoryClass = s.profile.homeCategoryClass;
      _tailwheel = s.profile.homeTailwheel;
      _otherClass = _categoryClass.isNotEmpty &&
          !CategoryClass.presets.contains(_categoryClass);
      if (_otherClass) c('otherClass').text = _categoryClass;
    }
  }

  String _hours(double v) => v == 0 ? '' : v.toStringAsFixed(1);
  String _count(int v) => v == 0 ? '' : '$v';

  void _fill(LogbookEntry e, {required bool includeTimes}) {
    c('type').text = e.aircraftType;
    c('tail').text = e.tailNumber;
    c('from').text = e.from;
    c('to').text = e.to;
    c('route').text = e.route;
    _categoryClass = e.categoryClass;
    _otherClass = _categoryClass.isNotEmpty &&
        !CategoryClass.presets.contains(_categoryClass.toUpperCase());
    if (_otherClass) c('otherClass').text = _categoryClass;
    _tailwheel = e.tailwheel;
    _ifr = e.conditions.toUpperCase() == 'IFR';
    _nightFlight = e.nightFlight;
    if (!includeTimes) return;
    c('total').text = _hours(e.totalTime);
    c('pic').text = _hours(e.picTime);
    c('sic').text = _hours(e.sicTime);
    c('dual').text = _hours(e.dualReceived);
    c('solo').text = _hours(e.soloTime);
    c('cfi').text = _hours(e.cfiGiven);
    c('xc').text = _hours(e.crossCountry);
    c('night').text = _hours(e.night);
    c('actual').text = _hours(e.actualInstrument);
    c('sim').text = _hours(e.simulatedInstrument);
    c('dayTo').text = _count(e.dayTakeoffs);
    c('dayLdg').text = _count(e.dayLandings);
    c('dayFullStop').text = _count(e.dayFullStopLandings);
    c('nightTo').text = _count(e.nightTakeoffs);
    c('nightLdg').text = _count(e.nightLandings);
    c('approaches').text = _count(e.approaches);
    c('remarks').text = e.remarks;
    _holding = e.holding;
    _tracking = e.tracking;
    _flightReview = e.flightReview;
    _ipc = e.ipc;
    _practicalTest = e.practicalTest;
  }

  @override
  void dispose() {
    for (final ctrl in _c.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Builds the entry from the form, or null with errors shown.
  LogbookEntry? buildEntry() {
    _cross = {};
    final fieldsOk = _formKey.currentState?.validate() ?? false;
    if (!fieldsOk) {
      setState(() {});
      return null;
    }
    double h(String k) => parseHours(c(k).text).value ?? 0;
    int n(String k) => parseCount(c(k).text).value ?? 0;
    final cc = _otherClass ? c('otherClass').text.trim() : _categoryClass;
    final e = LogbookEntry(
      id: widget.existing?.id,
      date: _date,
      aircraftType: c('type').text.trim(),
      tailNumber: c('tail').text.trim().toUpperCase(),
      categoryClass: cc,
      tailwheel: _tailwheel,
      from: c('from').text.trim().toUpperCase(),
      to: c('to').text.trim().toUpperCase(),
      route: c('route').text.trim().toUpperCase(),
      totalTime: h('total'),
      picTime: h('pic'),
      sicTime: h('sic'),
      dualReceived: h('dual'),
      soloTime: h('solo'),
      cfiGiven: h('cfi'),
      crossCountry: h('xc'),
      night: h('night'),
      actualInstrument: h('actual'),
      simulatedInstrument: h('sim'),
      dayTakeoffs: n('dayTo'),
      dayLandings: n('dayLdg'),
      dayFullStopLandings: _tailwheel ? n('dayFullStop') : 0,
      nightTakeoffs: n('nightTo'),
      nightLandings: n('nightLdg'),
      approaches: n('approaches'),
      holding: _holding,
      tracking: _tracking,
      flightReview: _flightReview,
      ipc: _ipc,
      practicalTest: _practicalTest,
      conditions: _ifr ? 'IFR' : 'VFR',
      nightFlight: _nightFlight,
      remarks: c('remarks').text.trim(),
    );
    final cross = crossCheck(e);
    if (cross.isNotEmpty) {
      setState(() => _cross = cross);
      _formKey.currentState?.validate();
      return null;
    }
    return e;
  }

  Future<void> _save() async {
    final e = buildEntry();
    if (e == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Check the highlighted fields.')));
      return;
    }
    setState(() => _saving = true);
    final svc = context.read<LogbookService>();
    if (isEdit) {
      await svc.updateEntry(e);
    } else {
      await svc.addEntry(e);
    }
    if (!mounted) return;
    Navigator.of(context).pop(e);
  }

  void _logAgain(LogbookEntry last) {
    setState(() {
      c('type').text = last.aircraftType;
      c('tail').text = last.tailNumber;
      c('from').text = last.from;
      c('to').text = last.to;
      c('route').text = last.route;
      _categoryClass = last.categoryClass;
      _otherClass = _categoryClass.isNotEmpty &&
          !CategoryClass.presets.contains(_categoryClass.toUpperCase());
      if (_otherClass) c('otherClass').text = _categoryClass;
      _tailwheel = last.tailwheel;
    });
  }

  Future<void> _pickDate() async {
    final now = (widget.clock ?? DateTime.now)();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final last = context.watch<LogbookService>().lastEntry;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit flight' : 'Log a flight'),
        actions: [
          TextButton(
            key: const Key('entry-save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (!isEdit && widget.prefill == null && last != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  key: const Key('log-again'),
                  onPressed: () => _logAgain(last),
                  icon: const Icon(Icons.replay),
                  label: Text(
                    'Log again: ${last.aircraftType} ${last.tailNumber} '
                    '${last.from}→${last.to}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            const SectionHeader('Flight'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('entry-date'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(dayMonthYear(_date),
                        style: const TextStyle(fontFamily: AppFonts.mono)),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('VFR')),
                    ButtonSegment(value: true, label: Text('IFR')),
                  ],
                  selected: {_ifr},
                  onSelectionChanged: (s) => setState(() => _ifr = s.first),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Night flight'),
              value: _nightFlight,
              onChanged: (v) => setState(() => _nightFlight = v),
            ),
            const SizedBox(height: 8),
            const SectionHeader('Aircraft'),
            Row(children: [
              Expanded(child: _text('type', 'Aircraft type', hint: 'C172')),
              const SizedBox(width: 10),
              Expanded(child: _text('tail', 'Tail number', hint: 'N12345', caps: true)),
            ]),
            const SizedBox(height: 10),
            Text('Category / class',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in CategoryClass.presets)
                  ChoiceChip(
                    label: Text(p),
                    tooltip: CategoryClass.label(p),
                    selected: !_otherClass && _categoryClass.toUpperCase() == p,
                    onSelected: (_) => setState(() {
                      _otherClass = false;
                      _categoryClass = p;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Other'),
                  selected: _otherClass,
                  onSelected: (_) => setState(() => _otherClass = true),
                ),
              ],
            ),
            if (_otherClass)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _text('otherClass', 'Category/class',
                    hint: 'e.g. Glider, Rotorcraft helicopter'),
              ),
            if (_cross['categoryClass'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_cross['categoryClass']!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tailwheel'),
              subtitle: const Text('61.57(a) then counts full-stop landings only'),
              value: _tailwheel,
              onChanged: (v) => setState(() => _tailwheel = v),
            ),
            const SectionHeader('Route'),
            Row(children: [
              Expanded(child: _text('from', 'From', hint: 'ICAO', caps: true, mono: true)),
              const SizedBox(width: 10),
              Expanded(child: _text('to', 'To', hint: 'ICAO', caps: true, mono: true)),
            ]),
            const SizedBox(height: 10),
            _text('route', 'Route (optional)', caps: true, mono: true),
            const SizedBox(height: 14),
            const SectionHeader('Time', subtitle: 'Hours and tenths. Blank = 0.'),
            _grid([
              _hoursField('total', 'Total'),
              _hoursField('pic', 'PIC'),
              _hoursField('sic', 'SIC'),
              _hoursField('dual', 'Dual received'),
              _hoursField('solo', 'Solo'),
              _hoursField('cfi', 'CFI given'),
              _hoursField('xc', 'Cross-country'),
              _hoursField('night', 'Night'),
              _hoursField('actual', 'Actual instrument'),
              _hoursField('sim', 'Simulated instrument'),
            ]),
            const SizedBox(height: 14),
            const SectionHeader('Takeoffs & landings'),
            _grid([
              _countField('dayTo', 'Day takeoffs'),
              _countField('dayLdg', 'Day landings'),
              if (_tailwheel) _countField('dayFullStop', 'Day full-stop landings'),
              _countField('nightTo', 'Night takeoffs'),
              _countField('nightLdg', 'Night full-stop landings'),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Night = 1 h after sunset to 1 h before sunrise (61.57(b)).',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeader('Instrument'),
            _grid([_countField('approaches', 'Approaches')]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Holding procedures'),
              value: _holding,
              onChanged: (v) => setState(() => _holding = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Intercepting & tracking courses'),
              value: _tracking,
              onChanged: (v) => setState(() => _tracking = v),
            ),
            const SectionHeader('Checks'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flight review (61.56)'),
              value: _flightReview,
              onChanged: (v) => setState(() => _flightReview = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Instrument proficiency check (61.57(d))'),
              value: _ipc,
              onChanged: (v) => setState(() => _ipc = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Practical test passed'),
              value: _practicalTest,
              onChanged: (v) => setState(() => _practicalTest = v),
            ),
            const SizedBox(height: 8),
            _text('remarks', 'Remarks', maxLines: 3),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(isEdit ? 'Save changes' : 'Save flight'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 560 ? 3 : 2;
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    });
  }

  Widget _text(String key, String label,
      {String? hint, bool caps = false, bool mono = false, int maxLines = 1}) {
    return TextFormField(
      key: Key('entry-$key'),
      controller: c(key),
      maxLines: maxLines,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.sentences,
      style: mono ? const TextStyle(fontFamily: AppFonts.mono) : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (_) => _cross[key],
    );
  }

  Widget _hoursField(String key, String label) {
    return TextFormField(
      key: Key('entry-$key'),
      controller: c(key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontFamily: AppFonts.mono),
      decoration: InputDecoration(labelText: label, hintText: '0.0'),
      validator: (v) => parseHours(v ?? '').error ?? _cross[key],
    );
  }

  Widget _countField(String key, String label) {
    return TextFormField(
      key: Key('entry-$key'),
      controller: c(key),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
      style: const TextStyle(fontFamily: AppFonts.mono),
      decoration: InputDecoration(labelText: label, hintText: '0'),
      validator: (v) => parseCount(v ?? '').error ?? _cross[key],
    );
  }

  // Exposed for tests.
  @visibleForTesting
  List<String> get hourFieldKeys => _hourFields;
  @visibleForTesting
  List<String> get countFieldKeys => _countFields;
}
