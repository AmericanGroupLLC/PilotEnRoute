import 'package:flutter/material.dart';

import '../core/legality/legality_engine.dart';
import '../core/minimums/go_check.dart';
import '../core/minimums/minimums_check.dart';
import 'theme.dart';

/// The meaning of a status, independent of colour.
enum Tone { go, caution, stop, neutral }

class StatusLook {
  final String label;
  final IconData icon;
  final Tone tone;
  const StatusLook(this.label, this.icon, this.tone);
}

/// Text-safe colour for a tone (icons, labels, borders).
Color toneColor(BuildContext context, Tone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (tone) {
    case Tone.go:
      return dark ? Sky.nightGo : Sky.go;
    case Tone.caution:
      return dark ? Sky.nightCaution : Sky.caution;
    case Tone.stop:
      return dark ? Sky.nightStop : Sky.stop;
    case Tone.neutral:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Soft tint behind a tone (pill and banner backgrounds).
Color toneSoft(BuildContext context, Tone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) return toneColor(context, tone).withValues(alpha: 0.16);
  switch (tone) {
    case Tone.go:
      return Sky.goSoft;
    case Tone.caution:
      return Sky.cautionSoft;
    case Tone.stop:
      return Sky.stopSoft;
    case Tone.neutral:
      return Theme.of(context).colorScheme.surfaceContainer;
  }
}

StatusLook lookForRule(RuleStatus r) {
  if (!r.required) {
    return const StatusLook('N/A', Icons.remove_circle_outline, Tone.neutral);
  }
  switch (r.state) {
    case RuleState.valid:
      return const StatusLook('VALID', Icons.check_circle, Tone.go);
    case RuleState.exempt:
      return const StatusLook('NOT REQ', Icons.check_circle_outline, Tone.go);
    case RuleState.grace:
      return const StatusLook('LAPSED', Icons.error, Tone.stop);
    case RuleState.lapsed:
      return const StatusLook('LAPSED', Icons.error, Tone.stop);
    case RuleState.ipcRequired:
      return const StatusLook('IPC REQ', Icons.error, Tone.stop);
    case RuleState.unknown:
      return const StatusLook('NO DATA', Icons.help, Tone.stop);
  }
}

StatusLook lookForCheck(CheckState s) {
  switch (s) {
    case CheckState.inside:
      return const StatusLook('INSIDE', Icons.check_circle, Tone.go);
    case CheckState.near:
      return const StatusLook('NEAR', Icons.warning_amber, Tone.caution);
    case CheckState.outside:
      return const StatusLook('OUTSIDE', Icons.cancel, Tone.stop);
    case CheckState.notSet:
      return const StatusLook(
        'NOT SET',
        Icons.remove_circle_outline,
        Tone.neutral,
      );
    case CheckState.unknown:
      return const StatusLook('UNKNOWN', Icons.help, Tone.neutral);
  }
}

StatusLook lookForVerdict(GoVerdict v) {
  switch (v) {
    case GoVerdict.inside:
      return const StatusLook('INSIDE & LEGAL', Icons.check_circle, Tone.go);
    case GoVerdict.outside:
      return const StatusLook('OUTSIDE MINIMUMS', Icons.cancel, Tone.stop);
    case GoVerdict.notLegal:
      return const StatusLook('NOT LEGAL', Icons.block, Tone.stop);
    case GoVerdict.incomplete:
      return const StatusLook('CHECK INCOMPLETE', Icons.help, Tone.caution);
  }
}

/// A status pill: a soft tinted capsule with the icon and the word in the
/// tone colour. The word and the icon carry the meaning; the colour only
/// repeats it. Neutral states get an outlined capsule.
class StatusTag extends StatelessWidget {
  const StatusTag(this.look, {super.key, this.dense = false});

  final StatusLook look;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, look.tone);
    final neutral = look.tone == Tone.neutral;
    final h = dense ? 24.0 : 28.0;
    return Semantics(
      label: look.label,
      excludeSemantics: true,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10),
        decoration: ShapeDecoration(
          color: neutral ? Colors.transparent : toneSoft(context, look.tone),
          shape: StadiumBorder(
            side: neutral
                ? BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1.2,
                  )
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(look.icon, size: dense ? 14 : 16, color: color),
            const SizedBox(width: 5),
            Text(
              look.label,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11 : 12.5,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
