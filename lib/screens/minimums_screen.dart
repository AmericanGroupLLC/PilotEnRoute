import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/minimums/personal_minimums.dart';
import '../services/settings_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The pilot's own personal minimums, day and night. Every field starts
/// blank and the app never proposes a number.
class MinimumsScreen extends StatefulWidget {
  const MinimumsScreen({super.key});

  @override
  State<MinimumsScreen> createState() => _MinimumsScreenState();
}

class _MinimumsScreenState extends State<MinimumsScreen> {
  final _form = GlobalKey<MinimumsFormState>();

  Future<void> _save() async {
    final m = _form.currentState!.read();
    if (m == null) return;
    await context.read<SettingsStore>().setMinimums(m);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Minimums saved')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = context.read<SettingsStore>().minimums;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal minimums'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MinimumsForm(key: _form, initial: current),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save minimums')),
        ],
      ),
    );
  }
}

/// Day and night limit fields. Shared by Settings and onboarding.
class MinimumsForm extends StatefulWidget {
  const MinimumsForm({super.key, this.initial = PersonalMinimums.blank});
  final PersonalMinimums initial;

  @override
  State<MinimumsForm> createState() => MinimumsFormState();
}

class MinimumsFormState extends State<MinimumsForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};

  static const fields = <(String, String, String)>[
    ('ceilingFt', 'Lowest ceiling', 'ft'),
    ('visibilitySm', 'Lowest visibility', 'sm'),
    ('maxWindKt', 'Highest wind', 'kt'),
    ('maxGustKt', 'Highest gust', 'kt'),
    ('maxCrosswindKt', 'Highest crosswind', 'kt'),
  ];

  TextEditingController c(String k) => _c.putIfAbsent(k, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    void fill(String prefix, MinimumsSet s) {
      String v(num? n) => n == null
          ? ''
          : (n == n.roundToDouble() ? n.toInt().toString() : n.toString());
      c('$prefix.ceilingFt').text = v(s.ceilingFt);
      c('$prefix.visibilitySm').text = v(s.visibilitySm);
      c('$prefix.maxWindKt').text = v(s.maxWindKt);
      c('$prefix.maxGustKt').text = v(s.maxGustKt);
      c('$prefix.maxCrosswindKt').text = v(s.maxCrosswindKt);
    }

    fill('day', widget.initial.day);
    fill('night', widget.initial.night);
  }

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  String? _validate(String key, String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || v < 0) return 'Enter a positive number';
    if (!key.endsWith('visibilitySm') && v != v.roundToDouble()) {
      return 'Whole numbers';
    }
    if (key.endsWith('ceilingFt') && v > 20000) return 'Too high';
    if (key.endsWith('visibilitySm') && v > 50) return 'Too high';
    if (key.endsWith('Kt') && v > 100) return 'Too high';
    return null;
  }

  /// The values typed, or null when a field is invalid.
  PersonalMinimums? read() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    int? i(String k) {
      final s = c(k).text.trim();
      return s.isEmpty ? null : double.parse(s).round();
    }

    double? d(String k) {
      final s = c(k).text.trim();
      return s.isEmpty ? null : double.parse(s);
    }

    MinimumsSet set(String p) => MinimumsSet(
          ceilingFt: i('$p.ceilingFt'),
          visibilitySm: d('$p.visibilitySm'),
          maxWindKt: i('$p.maxWindKt'),
          maxGustKt: i('$p.maxGustKt'),
          maxCrosswindKt: i('$p.maxCrosswindKt'),
        );
    return PersonalMinimums(day: set('day'), night: set('night'));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget column(String prefix, String title) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title),
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  key: Key('min-$prefix-${f.$1}'),
                  controller: c('$prefix.${f.$1}'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontFamily: AppFonts.mono),
                  decoration: InputDecoration(
                    labelText: f.$2,
                    suffixText: f.$3,
                  ),
                  validator: (v) => _validate('$prefix.${f.$1}', v),
                ),
              ),
          ],
        );
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your own limits, the ones you would write on a card. Leave a '
            'field blank if you do not use that limit. PilotEnRoute never '
            'suggests values.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 560;
            final day = column('day', 'Day');
            final night = column('night', 'Night');
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: day),
                      const SizedBox(width: 16),
                      Expanded(child: night),
                    ],
                  )
                : Column(children: [day, const SizedBox(height: 8), night]);
          }),
        ],
      ),
    );
  }
}
