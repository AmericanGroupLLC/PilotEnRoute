/// One saved Go Card check: the inputs, the raw METAR/TAF and the result, so
/// the pilot can look back at what they saw before a flight.
library;

import 'go_check.dart';

class GoCheckRecord {
  final int? id;
  final DateTime createdAt;
  final String departure;
  final String destination;
  final DateTime plannedAt;
  final bool passengers;
  final bool night;
  final bool ifr;
  final String categoryClass;
  final GoVerdict verdict;
  final String headline;
  final String metarRaw;
  final String tafRaw;

  /// Plain-text lines: each legality and minimums line as shown.
  final String detail;

  const GoCheckRecord({
    this.id,
    required this.createdAt,
    required this.departure,
    required this.destination,
    required this.plannedAt,
    required this.passengers,
    required this.night,
    required this.ifr,
    required this.categoryClass,
    required this.verdict,
    required this.headline,
    required this.metarRaw,
    required this.tafRaw,
    required this.detail,
  });

  factory GoCheckRecord.fromResult({
    required GoResult result,
    required String departure,
    required String destination,
    required DateTime plannedAt,
    required DateTime createdAt,
  }) {
    final f = result.legal.flight;
    final lines = <String>[
      for (final r in result.legal.rules)
        '${r.title} (${r.cite}): ${r.summary}'
            '${r.shortfall == null ? '' : ' — ${r.shortfall}'}',
      if (result.metarCheck != null)
        for (final l in result.metarCheck!.lines)
          '${result.metarCheck!.source} ${l.label}: ${l.observed} '
              '(limit ${l.limit}, ${l.state.name})',
      for (final t in result.tafChecks)
        for (final l in t.lines)
          '${t.source} ${l.label}: ${l.observed} (limit ${l.limit}, '
              '${l.state.name})',
      if (result.tafNote != null) result.tafNote!,
    ];
    return GoCheckRecord(
      createdAt: createdAt,
      departure: departure,
      destination: destination,
      plannedAt: plannedAt,
      passengers: f.passengers,
      night: f.night,
      ifr: f.ifr,
      categoryClass: f.categoryClass,
      verdict: result.verdict,
      headline: result.headline,
      metarRaw: result.weather?.metar?.raw ?? '',
      tafRaw: result.weather?.taf?.raw ?? '',
      detail: lines.join('\n'),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'departure': departure,
        'destination': destination,
        'planned_at': plannedAt.toIso8601String(),
        'passengers': passengers ? 1 : 0,
        'night': night ? 1 : 0,
        'ifr': ifr ? 1 : 0,
        'category_class': categoryClass,
        'verdict': verdict.name,
        'headline': headline,
        'metar_raw': metarRaw,
        'taf_raw': tafRaw,
        'detail': detail,
      };

  factory GoCheckRecord.fromMap(Map<String, Object?> m) => GoCheckRecord(
        id: (m['id'] as num?)?.toInt(),
        createdAt: DateTime.parse(m['created_at'].toString()),
        departure: (m['departure'] ?? '').toString(),
        destination: (m['destination'] ?? '').toString(),
        plannedAt: DateTime.parse(m['planned_at'].toString()),
        passengers: (m['passengers'] as num?) == 1,
        night: (m['night'] as num?) == 1,
        ifr: (m['ifr'] as num?) == 1,
        categoryClass: (m['category_class'] ?? '').toString(),
        verdict: GoVerdict.values.firstWhere(
            (v) => v.name == m['verdict'],
            orElse: () => GoVerdict.incomplete),
        headline: (m['headline'] ?? '').toString(),
        metarRaw: (m['metar_raw'] ?? '').toString(),
        tafRaw: (m['taf_raw'] ?? '').toString(),
        detail: (m['detail'] ?? '').toString(),
      );

  GoCheckRecord withId(int id) => GoCheckRecord(
        id: id,
        createdAt: createdAt,
        departure: departure,
        destination: destination,
        plannedAt: plannedAt,
        passengers: passengers,
        night: night,
        ifr: ifr,
        categoryClass: categoryClass,
        verdict: verdict,
        headline: headline,
        metarRaw: metarRaw,
        tafRaw: tafRaw,
        detail: detail,
      );
}

/// History search: airport (departure or destination) and result filter.
List<GoCheckRecord> filterChecks(List<GoCheckRecord> all,
    {String airport = '', GoVerdict? verdict}) {
  final q = airport.trim().toUpperCase();
  return all
      .where((r) =>
          q.isEmpty ||
          r.departure.toUpperCase().contains(q) ||
          r.destination.toUpperCase().contains(q))
      .where((r) => verdict == null || r.verdict == verdict)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
