import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/legality/pilot_profile.dart';
import '../core/logbook/logbook_entry.dart';
import '../services/settings_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Pilot profile in Settings: medical, flight review, ratings, home
/// category/class. The legality engine works every date out from these.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late PilotProfile _p = context.read<SettingsStore>().profile;
  late final _name = TextEditingController(text: _p.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context
        .read<SettingsStore>()
        .setProfile(_p.copyWith(name: _name.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile saved')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilot profile'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (printed on the PDF export, optional)',
            ),
          ),
          const SizedBox(height: 16),
          AircraftClassPicker(
            value: _p.homeCategoryClass,
            tailwheel: _p.homeTailwheel,
            onChanged: (cc, tw) => setState(() =>
                _p = _p.copyWith(homeCategoryClass: cc, homeTailwheel: tw)),
          ),
          const SizedBox(height: 16),
          MedicalForm(
            profile: _p,
            onChanged: (p) => setState(() => _p = p),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save profile')),
        ],
      ),
    );
  }
}

/// Category/class chips plus a tailwheel switch.
class AircraftClassPicker extends StatefulWidget {
  const AircraftClassPicker({
    super.key,
    required this.value,
    required this.tailwheel,
    required this.onChanged,
  });

  final String value;
  final bool tailwheel;
  final void Function(String categoryClass, bool tailwheel) onChanged;

  @override
  State<AircraftClassPicker> createState() => _AircraftClassPickerState();
}

class _AircraftClassPickerState extends State<AircraftClassPicker> {
  late bool _other = widget.value.isNotEmpty &&
      !CategoryClass.presets.contains(widget.value.toUpperCase());
  late final _otherCtrl = TextEditingController(text: _other ? widget.value : '');

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('What you fly',
            subtitle: 'Category and class for passenger currency'),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final p in CategoryClass.presets)
            ChoiceChip(
              key: Key('class-$p'),
              label: Text(p),
              tooltip: CategoryClass.label(p),
              selected: !_other && widget.value.toUpperCase() == p,
              onSelected: (_) {
                setState(() => _other = false);
                widget.onChanged(p, widget.tailwheel);
              },
            ),
          ChoiceChip(
            label: const Text('Other'),
            selected: _other,
            onSelected: (_) {
              setState(() => _other = true);
              widget.onChanged(_otherCtrl.text.trim(), widget.tailwheel);
            },
          ),
        ]),
        if (_other)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _otherCtrl,
              decoration: const InputDecoration(
                  labelText: 'Category/class', hintText: 'e.g. Glider'),
              onChanged: (t) => widget.onChanged(t.trim(), widget.tailwheel),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tailwheel'),
          value: widget.tailwheel,
          onChanged: (v) => widget.onChanged(
              _other ? _otherCtrl.text.trim() : widget.value, v),
        ),
      ],
    );
  }
}

/// Medical (class, exam date, the under-40 question, or BasicMed), flight
/// review, instrument rating and student solo endorsement.
class MedicalForm extends StatelessWidget {
  const MedicalForm({super.key, required this.profile, required this.onChanged});

  final PilotProfile profile;
  final ValueChanged<PilotProfile> onChanged;

  Future<DateTime?> _pick(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
    );
  }

  Widget _dateButton(BuildContext context, String label, DateTime? value,
      ValueChanged<DateTime> set,
      {Key? key}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        key: key,
        onPressed: () async {
          final d = await _pick(context, value);
          if (d != null) set(d);
        },
        icon: const Icon(Icons.event, size: 18),
        label: Text(
          '$label: ${value == null ? 'not set' : dayMonthYear(value)}',
          style: const TextStyle(fontFamily: AppFonts.body),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final scheme = Theme.of(context).colorScheme;
    final medical = p.medicalKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Medical', subtitle: '14 CFR 61.23'),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final k in MedicalKind.values)
            ChoiceChip(
              key: Key('medical-${k.name}'),
              label: Text(switch (k) {
                MedicalKind.none => 'None',
                MedicalKind.first => 'First class',
                MedicalKind.second => 'Second class',
                MedicalKind.third => 'Third class',
                MedicalKind.basicMed => 'BasicMed',
              }),
              selected: medical == k,
              onSelected: (_) => onChanged(p.copyWith(medicalKind: k)),
            ),
        ]),
        if (medical == MedicalKind.first ||
            medical == MedicalKind.second ||
            medical == MedicalKind.third) ...[
          _dateButton(context, 'Exam date on the certificate',
              p.medicalExamDate, (d) => onChanged(p.copyWith(medicalExamDate: d)),
              key: const Key('medical-exam-date')),
          const SizedBox(height: 8),
          const Text('Were you 40 or older on that exam date?'),
          Wrap(spacing: 6, children: [
            ChoiceChip(
              key: const Key('age-under40'),
              label: const Text('Under 40'),
              selected: p.age40OrOlderAtExam == false,
              onSelected: (_) => onChanged(p.copyWith(age40OrOlderAtExam: false)),
            ),
            ChoiceChip(
              key: const Key('age-40plus'),
              label: const Text('40 or older'),
              selected: p.age40OrOlderAtExam == true,
              onSelected: (_) => onChanged(p.copyWith(age40OrOlderAtExam: true)),
            ),
          ]),
          Text('No date of birth is stored.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
        if (medical == MedicalKind.basicMed) ...[
          _dateButton(context, 'Comprehensive medical exam (CMEC)',
              p.basicMedExamDate, (d) => onChanged(p.copyWith(basicMedExamDate: d))),
          _dateButton(context, 'Medical education course',
              p.basicMedCourseDate,
              (d) => onChanged(p.copyWith(basicMedCourseDate: d))),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<MedicalPrivilege>(
          initialValue: p.privilege,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Privileges you exercise'),
          items: [
            for (final m in MedicalPrivilege.values)
              DropdownMenuItem(
                  value: m,
                  child: Text(m.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (m) => onChanged(p.copyWith(privilege: m)),
        ),
        const SizedBox(height: 16),
        const SectionHeader('Flight review', subtitle: '14 CFR 61.56'),
        _dateButton(context, 'Last flight review', p.flightReviewDate,
            (d) => onChanged(p.copyWith(flightReviewDate: d)),
            key: const Key('flight-review-date')),
        Text(
          'Logbook entries flagged "Flight review" or "Practical test" count '
          'too; the latest one wins.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Instrument rated'),
          subtitle: const Text('Turns on the 61.57(c) IFR currency check'),
          value: p.instrumentRated,
          onChanged: (v) => onChanged(p.copyWith(instrumentRated: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Student pilot'),
          value: p.studentPilot,
          onChanged: (v) => onChanged(p.copyWith(studentPilot: v)),
        ),
        if (p.studentPilot)
          _dateButton(context, 'Solo endorsement (61.87(n))',
              p.soloEndorsementDate,
              (d) => onChanged(p.copyWith(soloEndorsementDate: d))),
      ],
    );
  }
}
