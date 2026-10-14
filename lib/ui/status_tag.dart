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

Color toneColor(BuildContext context, Tone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (tone) {
    case Tone.go:
      return dark ? const Color(0xFF5CC277) : Rbf.goGreen;
    case Tone.caution:
      return Rbf.caution;
    case Tone.stop:
      return dark ? Rbf.darkRed : Rbf.tagRed;
    case Tone.neutral:
      return Theme.of(context).colorScheme.outline;
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
      return const StatusLook('NOT SET', Icons.remove_circle_outline,
          Tone.neutral);
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

/// A status chip drawn as a Remove-Before-Flight tag: a pointed end with a
/// punched hole, then the icon and the word. The word and the icon carry the
/// meaning; the colour only repeats it.
class StatusTag extends StatelessWidget {
  const StatusTag(this.look, {super.key, this.dense = false});

  final StatusLook look;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, look.tone);
    final filled = look.tone != Tone.neutral;
    final fg = filled
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Rbf.panelBlack)
        : color;
    final h = dense ? 22.0 : 26.0;
    return Semantics(
      label: look.label,
      excludeSemantics: true,
      child: CustomPaint(
        painter: TagPainter(color: color, filled: filled),
        child: Container(
          height: h,
          padding: EdgeInsets.only(left: h * 0.78, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(look.icon, size: dense ? 13 : 15, color: fg),
              const SizedBox(width: 4),
              Text(
                look.label,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 11.5 : 13,
                  letterSpacing: 0.6,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tag outline: pointed left end, square right end with the 6 px radius, and
/// a punched hole that shows the background through it.
class TagPainter extends CustomPainter {
  TagPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  static Path outline(Size size) {
    final h = size.height;
    final w = size.width;
    final p = h * 0.42; // length of the pointed end
    const r = Rbf.radius;
    return Path()
      ..moveTo(p, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(p, h)
      ..lineTo(0, h / 2)
      ..close();
  }

  static Path hole(Size size) {
    final h = size.height;
    return Path()
      ..addOval(Rect.fromCircle(
          center: Offset(h * 0.46, h / 2), radius: h * 0.13));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path.combine(PathOperation.difference, outline(size), hole(size));
    if (filled) {
      canvas.drawPath(shape, Paint()..color = color);
    } else {
      canvas.drawPath(
          shape,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }
  }

  @override
  bool shouldRepaint(TagPainter old) =>
      old.color != color || old.filled != filled;
}
