/// Compares one weather report (a METAR or one TAF group) with the pilot's
/// own limits and words the result. Pure Dart.
///
/// Wording rule: nothing here ever says "safe". A line is inside, near (within
/// 80 % of the limit), outside, not set, or not reported.
library;

import '../weather/awc_models.dart';
import 'personal_minimums.dart';
import 'runway_wind.dart';

enum CheckState { inside, near, outside, notSet, unknown }

class MinimumLine {
  final String key;
  final String label;

  /// What was reported: "OVC 1300 ft", "None reported", "10+ sm".
  final String observed;

  /// The pilot's limit: "≥ 1500 ft", "≤ 10 kt", or "Not set".
  final String limit;
  final CheckState state;

  /// Extra: runway and head/tailwind for the crosswind line.
  final String? detail;

  /// The phrase used in the one-line result when this is outside:
  /// "crosswind 14 kt on 31 > your 10 kt".
  final String? outsidePhrase;

  const MinimumLine({
    required this.key,
    required this.label,
    required this.observed,
    required this.limit,
    required this.state,
    this.detail,
    this.outsidePhrase,
  });
}

class MinimumsResult {
  /// "METAR 13:52Z" or "TAF FM 14:00Z".
  final String source;
  final List<MinimumLine> lines;
  final RunwayWind? runwayWind;

  const MinimumsResult({
    required this.source,
    required this.lines,
    required this.runwayWind,
  });

  bool get anyOutside => lines.any((l) => l.state == CheckState.outside);
  bool get anyNear => lines.any((l) => l.state == CheckState.near);

  MinimumLine? get firstOutside {
    for (final l in lines) {
      if (l.state == CheckState.outside) return l;
    }
    return null;
  }
}

String _ft(int v) => '$v ft';
String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Near = within 80 % of a maximum, or a minimum within 80 % of the value.
CheckState _max(num value, num limit) {
  if (value > limit) return CheckState.outside;
  if (limit > 0 && value >= 0.8 * limit) return CheckState.near;
  return CheckState.inside;
}

CheckState _min(num value, num limit) {
  if (value < limit) return CheckState.outside;
  if (value > 0 && limit >= 0.8 * value) return CheckState.near;
  return CheckState.inside;
}

MinimumsResult checkAgainst({
  required String source,
  required MinimumsSet set,
  required int? ceilingFt,
  required List<CloudLayer> clouds,
  required Visibility? visibility,
  required Wind? wind,
  required List<RunwayInfo> runways,
  bool partial = false,
}) {
  final lines = <MinimumLine>[];

  // Ceiling — "none reported" is not zero.
  {
    final layer = clouds
        .where((c) => c.isCeiling && c.baseFt == ceilingFt)
        .map((c) => c.cover == 'OVX' ? 'VV' : c.cover)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final observed = ceilingFt == null
        ? (partial && clouds.isEmpty ? 'Not in this group' : 'None reported')
        : '${layer ?? 'Ceiling'} ${_ft(ceilingFt)}';
    final lim = set.ceilingFt;
    CheckState state;
    if (lim == null) {
      state = CheckState.notSet;
    } else if (ceilingFt == null) {
      state = partial && clouds.isEmpty ? CheckState.unknown : CheckState.inside;
    } else {
      state = _min(ceilingFt, lim);
    }
    lines.add(MinimumLine(
      key: 'ceiling',
      label: 'Ceiling',
      observed: observed,
      limit: lim == null ? 'Not set' : '≥ ${_ft(lim)}',
      state: state,
      outsidePhrase: state == CheckState.outside
          ? 'ceiling ${_ft(ceilingFt!)} < your ${_ft(lim!)}'
          : null,
    ));
  }

  // Visibility — "10+" is at least 10.
  {
    final lim = set.visibilitySm;
    CheckState state;
    String? detail;
    if (lim == null) {
      state = CheckState.notSet;
    } else if (visibility == null) {
      state = CheckState.unknown;
    } else if (visibility.orLess) {
      state = visibility.miles <= lim ? CheckState.outside : _min(visibility.miles, lim);
    } else if (visibility.orMore && visibility.miles < lim) {
      state = CheckState.unknown;
      detail = 'Reported as ${visibility.text}; cannot confirm your '
          '${_num(lim)} sm.';
    } else {
      state = _min(visibility.miles, lim);
      if (visibility.orMore && state == CheckState.near) {
        state = CheckState.inside;
      }
    }
    lines.add(MinimumLine(
      key: 'visibility',
      label: 'Visibility',
      observed: visibility?.text ??
          (partial ? 'Not in this group' : 'Not reported'),
      limit: lim == null ? 'Not set' : '≥ ${_num(lim)} sm',
      state: state,
      detail: detail,
      outsidePhrase: state == CheckState.outside
          ? 'visibility ${visibility!.text} < your ${_num(lim!)} sm'
          : null,
    ));
  }

  // Wind (sustained).
  {
    final lim = set.maxWindKt;
    final w = wind;
    final state = lim == null
        ? CheckState.notSet
        : w == null
            ? CheckState.unknown
            : _max(w.speedKt, lim);
    lines.add(MinimumLine(
      key: 'wind',
      label: 'Wind',
      observed: w?.text ?? (partial ? 'Not in this group' : 'Not reported'),
      limit: lim == null ? 'Not set' : '≤ $lim kt',
      state: state,
      outsidePhrase: state == CheckState.outside
          ? 'wind ${w!.speedKt} kt > your $lim kt'
          : null,
    ));
  }

  // Gust.
  {
    final lim = set.maxGustKt;
    final w = wind;
    final gust = w?.gustKt;
    final state = lim == null
        ? CheckState.notSet
        : w == null
            ? CheckState.unknown
            : gust == null
                ? CheckState.inside
                : _max(gust, lim);
    lines.add(MinimumLine(
      key: 'gust',
      label: 'Gust',
      observed: w == null
          ? (partial ? 'Not in this group' : 'Not reported')
          : gust == null
              ? 'No gust reported'
              : '$gust kt',
      limit: lim == null ? 'Not set' : '≤ $lim kt',
      state: state,
      outsidePhrase: state == CheckState.outside
          ? 'gust $gust kt > your $lim kt'
          : null,
    ));
  }

  // Crosswind on the best runway end.
  final rw = bestRunway(wind, runways);
  {
    final lim = set.maxCrosswindKt;
    CheckState state;
    String observed;
    String? detail;
    if (wind == null) {
      state = lim == null ? CheckState.notSet : CheckState.unknown;
      observed = partial ? 'Not in this group' : 'No wind report';
    } else if (rw == null) {
      state = lim == null ? CheckState.notSet : CheckState.unknown;
      observed = 'No runway alignment from AWC';
    } else {
      final x = rw.worstCrosswindKt;
      final gustPart = rw.gustCrosswindKt == null
          ? ''
          : ', gust ${rw.gustCrosswindKt} kt';
      observed = '${rw.crosswindKt} kt$gustPart on ${rw.variable ? 'any runway' : rw.end.name}';
      detail = rw.variable
          ? 'Wind variable: treated as full crosswind on every runway.'
          : rw.gustHeadwind == null
              ? 'Runway ${rw.end.name} (${rw.end.headingTrue}° true): '
                  '${rw.alongText}.'
              : 'Runway ${rw.end.name} (${rw.end.headingTrue}° true): '
                  '${rw.alongText}; in the gust '
                  '${RunwayWind(end: rw.end, crosswind: rw.gustCrosswind!, headwind: rw.gustHeadwind, gustCrosswind: null, gustHeadwind: null, variable: false).alongText}.';
      state = lim == null ? CheckState.notSet : _max(x, lim);
    }
    lines.add(MinimumLine(
      key: 'crosswind',
      label: 'Crosswind',
      observed: observed,
      limit: lim == null ? 'Not set' : '≤ $lim kt',
      state: state,
      detail: detail,
      outsidePhrase: state == CheckState.outside
          ? 'crosswind ${rw!.worstCrosswindKt} kt on '
              '${rw.variable ? 'any runway' : rw.end.name} > your $lim kt'
          : null,
    ));
  }

  return MinimumsResult(source: source, lines: lines, runwayWind: rw);
}
