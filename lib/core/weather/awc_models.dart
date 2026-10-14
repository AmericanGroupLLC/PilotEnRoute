/// Decoded Aviation Weather Center (aviationweather.gov) JSON: METAR, TAF and
/// airport. Pure Dart so every decoding rule is tested against recorded real
/// responses (test/fixtures/awc/).
///
/// Field meanings were read from real responses recorded on 2026-10-14:
/// `obsTime` is Unix seconds (UTC); `wdir` is degrees TRUE or the string
/// "VRB"; `visib` is a number in statute miles or a string such as "10+"
/// (METAR) / "6+" (TAF); `clouds[]` has `cover` (FEW/SCT/BKN/OVC/OVX) and
/// `base` in feet AGL; `altim` is hectopascals; runway `alignment` is the TRUE
/// heading of the first-named runway end.
library;

/// A visibility value. [orMore] is true for "10+" / "6+" / "P6SM".
class Visibility {
  final double miles;
  final bool orMore;
  final bool orLess;

  const Visibility(this.miles, {this.orMore = false, this.orLess = false});

  /// Parses 7, 0.25, "10+", "6+", "1/4", "1 1/2", "M1/4", "P6". Null when the
  /// value is absent or not a visibility.
  static Visibility? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return Visibility(raw.toDouble());
    var s = raw.toString().trim().toUpperCase().replaceAll('SM', '').trim();
    if (s.isEmpty) return null;
    var more = false, less = false;
    if (s.endsWith('+')) {
      more = true;
      s = s.substring(0, s.length - 1);
    }
    if (s.startsWith('P')) {
      more = true;
      s = s.substring(1);
    }
    if (s.startsWith('M')) {
      less = true;
      s = s.substring(1);
    }
    double? value;
    final parts = s.split(RegExp(r'\s+'));
    double? frac(String p) {
      final f = p.split('/');
      if (f.length != 2) return double.tryParse(p);
      final a = double.tryParse(f[0]);
      final b = double.tryParse(f[1]);
      if (a == null || b == null || b == 0) return null;
      return a / b;
    }

    if (parts.length == 2) {
      final whole = double.tryParse(parts[0]);
      final f = frac(parts[1]);
      if (whole != null && f != null) value = whole + f;
    } else if (parts.length == 1) {
      value = frac(parts[0]);
    }
    if (value == null) return null;
    return Visibility(value, orMore: more, orLess: less);
  }

  /// "10+ sm", "7 sm", "1/4 sm".
  String get text {
    String n;
    if (miles == miles.roundToDouble()) {
      n = miles.toInt().toString();
    } else if ((miles * 4).roundToDouble() == miles * 4 && miles < 3) {
      final whole = miles.floor();
      final q = ((miles - whole) * 4).round();
      final fr = switch (q) { 1 => '1/4', 2 => '1/2', 3 => '3/4', _ => '' };
      n = whole == 0 ? fr : '$whole $fr';
    } else {
      n = miles.toStringAsFixed(1);
    }
    return '${orLess ? '<' : ''}$n${orMore ? '+' : ''} sm';
  }
}

class CloudLayer {
  final String cover;
  final int? baseFt;
  const CloudLayer(this.cover, this.baseFt);

  bool get isCeiling => cover == 'BKN' || cover == 'OVC' || cover == 'OVX';

  static List<CloudLayer> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final c in raw)
        if (c is Map)
          CloudLayer((c['cover'] ?? '').toString().toUpperCase(),
              (c['base'] as num?)?.toInt()),
    ];
  }
}

/// The lowest broken, overcast or obscured (vertical visibility) layer, in
/// feet AGL. Null means no ceiling was reported — never zero.
///
/// AWC is not consistent about vertical visibility: a METAR carries
/// `vertVis: 1` (hundreds of feet) next to an OVX layer with `base: 100`,
/// while a TAF group carries `vertVis: 100` (feet) next to an OVX layer with
/// no base (KMBG, 2026-10-14). Callers pass it already in feet.
int? ceilingFrom(List<CloudLayer> clouds, {int? vertVisFt}) {
  int? lowest;
  var obscured = false;
  for (final c in clouds) {
    if (c.cover == 'OVX') obscured = true;
    if (!c.isCeiling || c.baseFt == null) continue;
    if (lowest == null || c.baseFt! < lowest) lowest = c.baseFt;
  }
  if (vertVisFt != null && (obscured || lowest == null)) {
    if (lowest == null || vertVisFt < lowest) lowest = vertVisFt;
  }
  return lowest;
}

/// Wind as reported. [directionTrue] is null for calm or variable.
class Wind {
  final int? directionTrue;
  final bool variable;
  final int speedKt;
  final int? gustKt;

  const Wind({
    required this.directionTrue,
    required this.variable,
    required this.speedKt,
    this.gustKt,
  });

  bool get calm => speedKt == 0 && (gustKt ?? 0) == 0;

  static Wind? from(Object? wdir, Object? wspd, Object? wgst) {
    if (wspd == null && wdir == null) return null;
    final speed = (wspd as num?)?.toInt() ?? 0;
    final gust = (wgst as num?)?.toInt();
    if (wdir is String && wdir.toUpperCase() == 'VRB') {
      return Wind(
          directionTrue: null, variable: true, speedKt: speed, gustKt: gust);
    }
    final dir = (wdir as num?)?.toInt();
    return Wind(
      directionTrue: speed == 0 ? null : dir,
      variable: false,
      speedKt: speed,
      gustKt: gust,
    );
  }

  /// "280° 5 kt", "VRB 4 kt", "Calm", "360° 12 G18 kt" (true).
  String get text {
    if (calm) return 'Calm';
    final d = variable
        ? 'VRB'
        : directionTrue == null
            ? '---'
            : '${directionTrue.toString().padLeft(3, '0')}°';
    final g = gustKt == null ? '' : ' G$gustKt';
    return '$d $speedKt$g kt';
  }
}

class MetarObservation {
  final String icao;
  final String name;
  final String raw;
  final DateTime? observedUtc;
  final Wind? wind;
  final Visibility? visibility;
  final List<CloudLayer> clouds;

  /// Feet AGL; null = no ceiling reported.
  final int? ceilingFt;
  final String flightCategory;
  final double? tempC;
  final double? dewpointC;

  /// Altimeter in hectopascals as AWC sends it.
  final double? altimeterHpa;
  final double? lat;
  final double? lon;

  const MetarObservation({
    required this.icao,
    required this.name,
    required this.raw,
    required this.observedUtc,
    required this.wind,
    required this.visibility,
    required this.clouds,
    required this.ceilingFt,
    required this.flightCategory,
    this.tempC,
    this.dewpointC,
    this.altimeterHpa,
    this.lat,
    this.lon,
  });

  double? get altimeterInHg =>
      altimeterHpa == null ? null : altimeterHpa! * 0.0295299830714;

  /// Minutes between the observation and [now]; null without an obs time.
  int? ageMinutes(DateTime now) => observedUtc == null
      ? null
      : now.toUtc().difference(observedUtc!).inMinutes;

  /// Older than 90 minutes is stale (a routine METAR is hourly).
  bool isStale(DateTime now) {
    final a = ageMinutes(now);
    return a == null || a > 90;
  }

  factory MetarObservation.fromJson(Map<dynamic, dynamic> j) {
    final clouds = CloudLayer.listFrom(j['clouds']);
    final obs = j['obsTime'];
    return MetarObservation(
      icao: (j['icaoId'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      raw: (j['rawOb'] ?? '').toString(),
      observedUtc: obs is num
          ? DateTime.fromMillisecondsSinceEpoch(obs.toInt() * 1000, isUtc: true)
          : null,
      wind: Wind.from(j['wdir'], j['wspd'], j['wgst']),
      visibility: Visibility.parse(j['visib']),
      clouds: clouds,
      ceilingFt: ceilingFrom(clouds,
          vertVisFt: j['vertVis'] is num
              ? ((j['vertVis'] as num) * 100).round()
              : null),
      flightCategory: (j['fltCat'] ?? '').toString(),
      tempC: (j['temp'] as num?)?.toDouble(),
      dewpointC: (j['dewp'] as num?)?.toDouble(),
      altimeterHpa: (j['altim'] as num?)?.toDouble(),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
    );
  }
}

class TafGroup {
  final DateTime fromUtc;
  final DateTime toUtc;

  /// null for the initial group, else FM / BECMG / TEMPO / PROB.
  final String? change;
  final int? probability;
  final Wind? wind;
  final Visibility? visibility;
  final List<CloudLayer> clouds;
  final int? ceilingFt;
  final String? weather;

  const TafGroup({
    required this.fromUtc,
    required this.toUtc,
    required this.change,
    required this.probability,
    required this.wind,
    required this.visibility,
    required this.clouds,
    required this.ceilingFt,
    this.weather,
  });

  /// "FM 14:00Z", "TEMPO", "PROB30", "Base".
  String get label {
    if (probability != null) {
      return 'PROB$probability${change == 'TEMPO' ? ' TEMPO' : ''}';
    }
    return change ?? 'Base';
  }

  bool get isTemporary => change == 'TEMPO' || change == 'PROB' ||
      probability != null;

  bool overlaps(DateTime startUtc, DateTime endUtc) =>
      fromUtc.isBefore(endUtc) && toUtc.isAfter(startUtc);

  factory TafGroup.fromJson(Map<dynamic, dynamic> j) {
    DateTime t(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch(((v as num?) ?? 0).toInt() * 1000,
            isUtc: true);
    final clouds = CloudLayer.listFrom(j['clouds']);
    final hasWind = j['wspd'] != null || j['wdir'] != null;
    return TafGroup(
      fromUtc: t(j['timeFrom']),
      toUtc: t(j['timeTo']),
      change: j['fcstChange']?.toString(),
      probability: (j['probability'] as num?)?.toInt(),
      wind: hasWind ? Wind.from(j['wdir'], j['wspd'], j['wgst']) : null,
      visibility: Visibility.parse(j['visib']),
      clouds: clouds,
      ceilingFt:
          ceilingFrom(clouds, vertVisFt: (j['vertVis'] as num?)?.round()),
      weather: j['wxString']?.toString(),
    );
  }
}

class TafReport {
  final String icao;
  final String raw;
  final DateTime? issuedUtc;
  final List<TafGroup> groups;

  const TafReport({
    required this.icao,
    required this.raw,
    required this.issuedUtc,
    required this.groups,
  });

  /// Every group that is in force at some point in [startUtc, endUtc).
  List<TafGroup> groupsBetween(DateTime startUtc, DateTime endUtc) =>
      groups.where((g) => g.overlaps(startUtc, endUtc)).toList();

  factory TafReport.fromJson(Map<dynamic, dynamic> j) {
    final fc = j['fcsts'];
    return TafReport(
      icao: (j['icaoId'] ?? '').toString(),
      raw: (j['rawTAF'] ?? '').toString(),
      issuedUtc: DateTime.tryParse((j['issueTime'] ?? '').toString()),
      groups: fc is List
          ? [for (final g in fc) if (g is Map) TafGroup.fromJson(g)]
          : const [],
    );
  }
}

/// One runway as AWC lists it: "13/31" with the true alignment of "13".
class RunwayInfo {
  final String id;
  final int? alignmentTrue;
  final String dimension;
  final String surface;

  const RunwayInfo({
    required this.id,
    required this.alignmentTrue,
    this.dimension = '',
    this.surface = '',
  });

  /// The two ends with their true headings: [("13", 142), ("31", 322)].
  /// Empty when AWC gives no alignment or the id is not a runway pair
  /// (helipads "H1", water lanes without a heading).
  List<RunwayEnd> get ends {
    final a = alignmentTrue;
    if (a == null) return const [];
    final names = id.split('/');
    if (names.length != 2) return const [];
    if (names.any((n) => n.trim().isEmpty || n.startsWith('H'))) {
      return const [];
    }
    return [
      RunwayEnd(names[0].trim(), a % 360),
      RunwayEnd(names[1].trim(), (a + 180) % 360),
    ];
  }
}

class RunwayEnd {
  final String name;
  final int headingTrue;
  const RunwayEnd(this.name, this.headingTrue);
}

/// Airport reference data from the AWC airport endpoint
/// (`/api/data/airport`), which republishes FAA data for US airports
/// (`source: "FAA"`) and carries a smaller international set.
class AirportReference {
  final String icao;
  final String name;
  final String state;
  final String country;
  final String source;

  /// Field elevation as published by AWC, in metres (KLAX reads 39).
  final int? elevationM;
  final String magneticVariation;

  /// True when AWC lists a control tower ("T"); false when none is listed.
  final bool towered;

  /// e.g. ["LCL/P 119.8", "D-ATIS 133.8"]; empty when none is listed.
  final List<String> frequencies;

  /// e.g. ["06L/24R 8926x150 ft"].
  final List<String> runways;

  /// Runways with their true alignment, for crosswind.
  final List<RunwayInfo> runwayInfo;
  final double? lat;
  final double? lon;

  const AirportReference({
    required this.icao,
    required this.name,
    required this.state,
    required this.country,
    required this.source,
    required this.elevationM,
    required this.magneticVariation,
    required this.towered,
    required this.frequencies,
    required this.runways,
    this.runwayInfo = const [],
    this.lat,
    this.lon,
  });

  int? get elevationFt =>
      elevationM == null ? null : (elevationM! * 3.28084).round();

  bool get isUs => country == 'US';

  factory AirportReference.fromJson(Map<dynamic, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();

    // "LCL/P,119.8;D-ATIS,133.8" — "-" when AWC lists none.
    final frequencies = <String>[];
    for (final entry in str('freqs').split(';')) {
      final parts = entry.split(',').map((p) => p.trim()).toList();
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        frequencies.add('${parts[0]} ${parts[1]}');
      }
    }

    final runways = <String>[];
    final info = <RunwayInfo>[];
    final rawRunways = json['runways'];
    if (rawRunways is List) {
      for (final r in rawRunways) {
        if (r is! Map) continue;
        final id = (r['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final dim = (r['dimension'] ?? '').toString().trim();
        runways.add(dim.isEmpty ? id : '$id $dim ft');
        final al = r['alignment'];
        info.add(RunwayInfo(
          id: id,
          alignmentTrue: al is num ? al.round() : int.tryParse('${al ?? ''}'),
          dimension: dim,
          surface: (r['surface'] ?? '').toString(),
        ));
      }
    }

    final elev = json['elev'];
    return AirportReference(
      icao: str('icaoId'),
      name: str('name'),
      state: str('state'),
      country: str('country'),
      source: str('source'),
      elevationM:
          elev is num ? elev.round() : int.tryParse(elev?.toString() ?? ''),
      magneticVariation: str('magdec'),
      towered: str('tower').toUpperCase() == 'T',
      frequencies: frequencies,
      runways: runways,
      runwayInfo: info,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}
