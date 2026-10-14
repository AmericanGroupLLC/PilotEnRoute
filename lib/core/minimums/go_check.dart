/// The Go Card's verdict: legality from the logbook plus the live weather
/// against the pilot's own minimums, worded in one line.
library;

import '../legality/date_text.dart';
import '../legality/legality_engine.dart';
import '../weather/awc_models.dart';
import 'minimums_check.dart';
import 'personal_minimums.dart';

/// How one AWC request ended.
enum FetchStatus {
  ok,

  /// 204 or an empty list: AWC has nothing for that identifier.
  noData,

  /// Reached the server, which answered with an error status.
  failed,

  /// Never reached the server (no network, DNS, timeout).
  offline,
}

class WeatherSnapshot {
  final String station;
  final FetchStatus metarStatus;
  final FetchStatus tafStatus;
  final FetchStatus airportStatus;
  final MetarObservation? metar;
  final TafReport? taf;
  final AirportReference? airport;

  /// When the app asked, for the saved history.
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.station,
    required this.metarStatus,
    required this.tafStatus,
    required this.airportStatus,
    required this.fetchedAt,
    this.metar,
    this.taf,
    this.airport,
  });

  /// Honest copy for why the METAR is missing, or null when it is there.
  String? get metarProblem => switch (metarStatus) {
        FetchStatus.ok => metar == null ? 'No METAR in the answer.' : null,
        FetchStatus.noData =>
          'aviationweather.gov has no current METAR for $station. Check the '
              'identifier (ICAO, e.g. KPAO).',
        FetchStatus.failed =>
          'aviationweather.gov answered with an error. Try again shortly.',
        FetchStatus.offline =>
          'Could not reach aviationweather.gov. You appear to be offline.',
      };
}

enum GoVerdict {
  /// Legal, and the weather is inside every limit that is set.
  inside,

  /// Legal, but at least one weather value is outside a limit.
  outside,

  /// A required currency/medical/review item is not met.
  notLegal,

  /// Legal, but the weather part could not be completed (no minimums set,
  /// no METAR, or a stale METAR).
  incomplete,
}

class GoResult {
  final LegalityReport legal;
  final WeatherSnapshot? weather;
  final MinimumsResult? metarCheck;

  /// One result per TAF group in force within ±1 h of departure.
  final List<MinimumsResult> tafChecks;

  /// Why the TAF part is empty, if it is.
  final String? tafNote;
  final GoVerdict verdict;
  final String headline;

  /// A second line when more than one thing is wrong.
  final String? secondLine;
  final bool metarStale;
  final bool minimumsSet;

  const GoResult({
    required this.legal,
    required this.weather,
    required this.metarCheck,
    required this.tafChecks,
    required this.tafNote,
    required this.verdict,
    required this.headline,
    required this.secondLine,
    required this.metarStale,
    required this.minimumsSet,
  });

  static const disclaimer = "Your decision, not the app's. Check an official "
      'briefing (1800wxbrief.com) before flight.';
}

/// Builds the Go Card result. [now] is injected for the stale check.
GoResult evaluateGo({
  required LegalityReport legal,
  required WeatherSnapshot? weather,
  required PersonalMinimums minimums,
  required DateTime departureLocal,
  required DateTime now,
}) {
  final set = minimums.forFlight(night: legal.flight.night);
  final runways = weather?.airport?.runwayInfo ?? const <RunwayInfo>[];

  MinimumsResult? metarCheck;
  var stale = false;
  final metar = weather?.metar;
  if (metar != null) {
    stale = metar.isStale(now);
    metarCheck = checkAgainst(
      source: metar.observedUtc == null
          ? 'METAR'
          : 'METAR ${zuluTime(metar.observedUtc!)}',
      set: set,
      ceilingFt: metar.ceilingFt,
      clouds: metar.clouds,
      visibility: metar.visibility,
      wind: metar.wind,
      runways: runways,
    );
  }

  final tafChecks = <MinimumsResult>[];
  String? tafNote;
  if (weather != null) {
    final taf = weather.taf;
    if (taf == null) {
      tafNote = switch (weather.tafStatus) {
        FetchStatus.noData => 'No TAF is issued for ${weather.station}.',
        FetchStatus.offline => 'TAF not fetched: offline.',
        FetchStatus.failed => 'TAF not fetched: aviationweather.gov error.',
        FetchStatus.ok => 'No TAF in the answer.',
      };
    } else {
      final dep = departureLocal.toUtc();
      final groups = taf.groupsBetween(
          dep.subtract(const Duration(hours: 1)),
          dep.add(const Duration(hours: 1)));
      if (groups.isEmpty) {
        tafNote = 'The TAF does not cover departure ±1 h.';
      }
      for (final g in groups) {
        tafChecks.add(checkAgainst(
          source: 'TAF ${g.label} ${zuluTime(g.fromUtc)}–${zuluTime(g.toUtc)}',
          set: set,
          ceilingFt: g.ceilingFt,
          clouds: g.clouds,
          visibility: g.visibility,
          wind: g.wind,
          runways: runways,
          partial: g.change == 'TEMPO' || g.change == 'BECMG' ||
              g.probability != null,
        ));
      }
    }
  }

  final minimumsSet = !set.isEmpty;
  String? outsidePhrase;
  if (metarCheck?.firstOutside != null) {
    outsidePhrase = metarCheck!.firstOutside!.outsidePhrase;
  } else {
    for (final t in tafChecks) {
      final o = t.firstOutside;
      if (o != null) {
        outsidePhrase = '${o.outsidePhrase} (${t.source})';
        break;
      }
    }
  }

  final notLegal = legal.notLegalLine;
  GoVerdict verdict;
  String headline;
  String? second;
  if (notLegal != null) {
    verdict = GoVerdict.notLegal;
    headline = notLegal;
    if (outsidePhrase != null) second = 'Outside your minimums: $outsidePhrase';
  } else if (!minimumsSet) {
    verdict = GoVerdict.incomplete;
    headline = 'Legal for this flight. Your '
        '${legal.flight.night ? 'night' : 'day'} minimums are not set, so the '
        'weather was not checked against them.';
  } else if (metar == null) {
    verdict = GoVerdict.incomplete;
    headline = 'Legal for this flight. Weather not checked: '
        '${weather?.metarProblem ?? 'no weather requested.'}';
  } else if (outsidePhrase != null) {
    verdict = GoVerdict.outside;
    headline = 'Outside your minimums: $outsidePhrase';
  } else if (stale) {
    verdict = GoVerdict.incomplete;
    final age = metar.ageMinutes(now);
    headline = 'Legal for this flight. The latest METAR is '
        '${age == null ? 'of unknown age' : '${age ~/ 60} h ${age % 60} min old'}'
        ', so it is not treated as current.';
  } else if (metarCheck!.lines.any((l) => l.state == CheckState.unknown)) {
    verdict = GoVerdict.incomplete;
    final which = metarCheck.lines
        .where((l) => l.state == CheckState.unknown)
        .map((l) => '${l.label.toLowerCase()} (${l.observed.toLowerCase()})')
        .join(', ');
    headline = 'Legal for this flight. Not every limit could be checked: '
        '$which.';
  } else {
    verdict = GoVerdict.inside;
    headline = 'Inside your minimums and legal for this flight';
  }

  return GoResult(
    legal: legal,
    weather: weather,
    metarCheck: metarCheck,
    tafChecks: tafChecks,
    tafNote: tafNote,
    verdict: verdict,
    headline: headline,
    secondLine: second,
    metarStale: stale,
    minimumsSet: minimumsSet,
  );
}
