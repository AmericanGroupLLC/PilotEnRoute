/// Crosswind and head/tailwind on the best runway end.
///
/// METAR wind direction and AWC runway `alignment` are both TRUE, so they are
/// compared directly. (KPAO 13/31 has alignment 142 and magdec 15E: 142 - 15
/// = 127 magnetic, which is runway 13.) Never mix in a magnetic runway number.
library;

import 'dart:math' as math;

import '../weather/awc_models.dart';

class RunwayWind {
  final RunwayEnd end;

  /// Steady crosswind, knots (always >= 0).
  final double crosswind;

  /// Steady headwind, knots; negative is a tailwind. Null when the wind is
  /// variable (no direction to resolve).
  final double? headwind;
  final double? gustCrosswind;
  final double? gustHeadwind;

  /// VRB wind: treated as full crosswind, from any direction.
  final bool variable;

  const RunwayWind({
    required this.end,
    required this.crosswind,
    required this.headwind,
    required this.gustCrosswind,
    required this.gustHeadwind,
    required this.variable,
  });

  int get crosswindKt => crosswind.round();
  int? get gustCrosswindKt => gustCrosswind?.round();

  /// The larger of steady and gust crosswind, rounded — what a limit is
  /// compared with.
  int get worstCrosswindKt =>
      math.max(crosswindKt, gustCrosswindKt ?? 0);

  /// "headwind 11 kt" / "tailwind 3 kt" / "no head/tailwind (variable)".
  String get alongText {
    if (variable || headwind == null) return 'direction variable';
    final h = headwind!.round();
    if (h == 0) return 'no headwind';
    return h > 0 ? 'headwind $h kt' : 'tailwind ${-h} kt';
  }
}

/// Components of [speed] from [windFrom] (true) on a runway heading
/// [heading] (true): (crosswind >= 0, headwind; negative = tailwind).
(double, double) components(int windFrom, int heading, num speed) {
  final rad = (windFrom - heading) * math.pi / 180;
  final cross = (speed * math.sin(rad)).abs();
  final head = speed * math.cos(rad);
  // Kill floating-point dust such as 1e-15 so 0 reads as 0.
  double tidy(double v) => v.abs() < 1e-9 ? 0 : v;
  return (tidy(cross), tidy(head));
}

/// The runway end with the least steady crosswind (ties go to the larger
/// headwind). Null when no runway has a usable alignment or there is no wind
/// report.
RunwayWind? bestRunway(Wind? wind, List<RunwayInfo> runways) {
  if (wind == null) return null;
  final ends = [for (final r in runways) ...r.ends];
  if (ends.isEmpty) return null;

  if (wind.calm) {
    return RunwayWind(
      end: ends.first,
      crosswind: 0,
      headwind: 0,
      gustCrosswind: null,
      gustHeadwind: null,
      variable: false,
    );
  }
  if (wind.variable || wind.directionTrue == null) {
    // VRB: any direction is possible, so the whole speed may be crosswind.
    return RunwayWind(
      end: ends.first,
      crosswind: wind.speedKt.toDouble(),
      headwind: null,
      gustCrosswind: wind.gustKt?.toDouble(),
      gustHeadwind: null,
      variable: true,
    );
  }

  RunwayWind? best;
  for (final e in ends) {
    final (x, h) = components(wind.directionTrue!, e.headingTrue, wind.speedKt);
    double? gx, gh;
    if (wind.gustKt != null) {
      final g = components(wind.directionTrue!, e.headingTrue, wind.gustKt!);
      gx = g.$1;
      gh = g.$2;
    }
    final candidate = RunwayWind(
      end: e,
      crosswind: x,
      headwind: h,
      gustCrosswind: gx,
      gustHeadwind: gh,
      variable: false,
    );
    if (best == null ||
        x < best.crosswind - 1e-9 ||
        ((x - best.crosswind).abs() < 1e-9 && h > (best.headwind ?? 0))) {
      best = candidate;
    }
  }
  return best;
}
