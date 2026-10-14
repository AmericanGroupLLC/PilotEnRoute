/// Best-runway crosswind, the minimums check and the Go Card wording,
/// against recorded real AWC answers (captured 2026-10-14T13:03:13Z).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/core/minimums/go_check.dart';
import 'package:pilot_enroute/core/minimums/minimums_check.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/core/minimums/runway_wind.dart';
import 'package:pilot_enroute/core/weather/awc_models.dart';

import '../support/awc_fixtures.dart';

MetarObservation metar(String s) => MetarObservation.fromJson(first('metar_$s'));
AirportReference airport(String s) =>
    AirportReference.fromJson(first('airport_$s'));
TafReport taf(String s) => TafReport.fromJson(first('taf_$s'));

const limits = MinimumsSet(
  ceilingFt: 2000,
  visibilitySm: 5,
  maxWindKt: 20,
  maxGustKt: 25,
  maxCrosswindKt: 10,
);

WeatherSnapshot snap(String s) => WeatherSnapshot(
      station: s,
      metarStatus: FetchStatus.ok,
      tafStatus: (fixture('taf_$s') as List).isEmpty
          ? FetchStatus.noData
          : FetchStatus.ok,
      airportStatus: FetchStatus.ok,
      metar: metar(s),
      taf: (fixture('taf_$s') as List).isEmpty ? null : taf(s),
      airport: airport(s),
      fetchedAt: capturedAt('metar_$s'),
    );

final legalProfile = PilotProfile(
  medicalKind: MedicalKind.third,
  medicalExamDate: DateTime(2026, 1, 10),
  age40OrOlderAtExam: false,
  flightReviewDate: DateTime(2026, 1, 10),
  homeCategoryClass: 'ASEL',
);

LegalityReport legal({bool night = false, List<LogbookEntry> entries = const []}) =>
    const LegalityEngine().evaluate(
      entries: entries,
      profile: legalProfile,
      flight: PlannedFlight(
          date: DateTime(2026, 10, 14), categoryClass: 'ASEL', night: night),
    );

void main() {
  group('best-runway crosswind', () {
    test('KACK 240/15G23: runway 24 (225 true), 4 kt, gust 6 kt', () {
      final rw = bestRunway(metar('KACK').wind, airport('KACK').runwayInfo)!;
      expect(rw.end.name, '24');
      expect(rw.end.headingTrue, 225);
      expect(rw.crosswindKt, 4);
      expect(rw.gustCrosswindKt, 6);
      expect(rw.worstCrosswindKt, 6);
      expect(rw.headwind!.round(), 14);
      expect(rw.alongText, 'headwind 14 kt');
    });

    test('KDLH 360/12G18: runway 03 (32 true) beats 27, 6 kt gust 10', () {
      final rw = bestRunway(metar('KDLH').wind, airport('KDLH').runwayInfo)!;
      expect(rw.end.name, '03');
      expect(rw.crosswindKt, 6);
      expect(rw.gustCrosswindKt, 10);
      expect(rw.headwind!.round(), 10);
    });

    test('both ends are tried: KPAO 280/5 picks 31 (headwind), not 13', () {
      final rw = bestRunway(metar('KPAO').wind, airport('KPAO').runwayInfo)!;
      expect(rw.end.name, '31');
      expect(rw.crosswindKt, 3);
      expect(rw.headwind, greaterThan(0));
    });

    test('a tailwind is reported as a tailwind', () {
      final (_, h) = components(280, 142, 5);
      expect(h, lessThan(0));
      final rw = RunwayWind(
          end: const RunwayEnd('13', 142),
          crosswind: 3,
          headwind: h,
          gustCrosswind: null,
          gustHeadwind: null,
          variable: false);
      expect(rw.alongText, 'tailwind 4 kt');
    });

    test('VRB is full crosswind on any runway (KPIA VRB04)', () {
      final rw = bestRunway(metar('KPIA').wind, airport('KPIA').runwayInfo)!;
      expect(rw.variable, isTrue);
      expect(rw.crosswindKt, 4);
      expect(rw.headwind, isNull);
      expect(rw.alongText, 'direction variable');
    });

    test('calm is zero (KMBG 00000KT)', () {
      final rw = bestRunway(metar('KMBG').wind, airport('KMBG').runwayInfo)!;
      expect(rw.crosswind, 0);
      expect(rw.headwind, 0);
    });

    test('no runway alignment, no answer', () {
      expect(
          bestRunway(metar('KACK').wind,
              const [RunwayInfo(id: '06/24', alignmentTrue: null)]),
          isNull);
    });

    test('straight down the runway is zero crosswind', () {
      final (x, h) = components(90, 90, 15);
      expect(x, 0);
      expect(h, 15);
    });

    test('90 degrees off is all crosswind', () {
      final (x, h) = components(180, 90, 15);
      expect(x, closeTo(15, 1e-9));
      expect(h, closeTo(0, 1e-9));
    });
  });

  group('minimums lines', () {
    MinimumsResult check(String s, MinimumsSet set) {
      final m = metar(s);
      return checkAgainst(
        source: 'METAR',
        set: set,
        ceilingFt: m.ceilingFt,
        clouds: m.clouds,
        visibility: m.visibility,
        wind: m.wind,
        runways: airport(s).runwayInfo,
      );
    }

    MinimumLine line(MinimumsResult r, String key) =>
        r.lines.firstWhere((l) => l.key == key);

    test('KDLH: OVC 1300 is below a 2000 ft ceiling', () {
      final r = check('KDLH', limits);
      final c = line(r, 'ceiling');
      expect(c.observed, 'OVC 1300 ft');
      expect(c.state, CheckState.outside);
      expect(c.outsidePhrase, 'ceiling 1300 ft < your 2000 ft');
    });

    test('KPAO: no ceiling reported passes and says so', () {
      final c = line(check('KPAO', limits), 'ceiling');
      expect(c.observed, 'None reported');
      expect(c.state, CheckState.inside);
    });

    test('"10+" visibility meets a 5 sm limit', () {
      final v = line(check('KPAO', limits), 'visibility');
      expect(v.observed, '10+ sm');
      expect(v.state, CheckState.inside);
    });

    test('"10+" cannot confirm a 15 sm limit', () {
      final v = line(check('KPAO', const MinimumsSet(visibilitySm: 15)),
          'visibility');
      expect(v.state, CheckState.unknown);
      expect(v.detail, contains('cannot confirm'));
    });

    test('KMBG 1/4 sm is below 5 sm', () {
      final v = line(check('KMBG', limits), 'visibility');
      expect(v.state, CheckState.outside);
      expect(v.outsidePhrase, 'visibility 1/4 sm < your 5 sm');
    });

    test('KACK gust 23 kt is near a 25 kt limit (within 80 %)', () {
      final g = line(check('KACK', limits), 'gust');
      expect(g.observed, '23 kt');
      expect(g.state, CheckState.near);
    });

    test('KACK gust 23 kt is outside a 20 kt gust limit', () {
      final g = line(check('KACK', const MinimumsSet(maxGustKt: 20)), 'gust');
      expect(g.state, CheckState.outside);
      expect(g.outsidePhrase, 'gust 23 kt > your 20 kt');
    });

    test('no gust reported passes a gust limit', () {
      final g = line(check('KPAO', limits), 'gust');
      expect(g.observed, 'No gust reported');
      expect(g.state, CheckState.inside);
    });

    test('crosswind is compared using the gust component', () {
      // KDLH: steady 6, gust 10 on 03.
      final x = line(check('KDLH', const MinimumsSet(maxCrosswindKt: 8)),
          'crosswind');
      expect(x.observed, '6 kt, gust 10 kt on 03');
      expect(x.state, CheckState.outside);
      expect(x.outsidePhrase, 'crosswind 10 kt on 03 > your 8 kt');
      expect(x.detail, contains('Runway 03 (32° true): headwind 10 kt'));
    });

    test('VRB crosswind says it is treated as full crosswind', () {
      final x = line(check('KPIA', limits), 'crosswind');
      expect(x.observed, '4 kt on any runway');
      expect(x.detail, contains('treated as full crosswind'));
    });

    test('a limit left blank is "not set", never a default', () {
      final r = check('KDLH', MinimumsSet.blank);
      for (final l in r.lines) {
        expect(l.state, CheckState.notSet);
        expect(l.limit, 'Not set');
      }
    });
  });

  group('Go Card result wording', () {
    GoResult go(String s,
        {MinimumsSet set = limits,
        DateTime? now,
        DateTime? departure,
        LegalityReport? report}) {
      return evaluateGo(
        legal: report ??
            legal(entries: [
              LogbookEntry(
                date: DateTime(2026, 10, 1),
                aircraftType: 'C172',
                tailNumber: 'N1',
                from: s,
                to: s,
                totalTime: 1,
                categoryClass: 'ASEL',
                dayTakeoffs: 3,
                dayLandings: 3,
              )
            ]),
        weather: snap(s),
        minimums: PersonalMinimums(day: set),
        departureLocal: departure ?? DateTime.utc(2026, 10, 14, 13, 30),
        now: now ?? capturedAt('metar_$s'),
      );
    }

    test('KSJC inside every limit: "Inside your minimums and legal"', () {
      final r = go('KSJC');
      expect(r.verdict, GoVerdict.inside);
      expect(r.headline, 'Inside your minimums and legal for this flight');
      expect(r.headline.toLowerCase(), isNot(contains('safe')));
    });

    test('KDLH: outside on ceiling, worded with the number and the limit', () {
      final r = go('KDLH');
      expect(r.verdict, GoVerdict.outside);
      expect(r.headline, 'Outside your minimums: ceiling 1300 ft < your 2000 ft');
    });

    test('crosswind headline names the runway', () {
      final r = go('KACK', set: const MinimumsSet(maxCrosswindKt: 5));
      expect(r.headline, 'Outside your minimums: crosswind 6 kt on 24 > your 5 kt');
    });

    test('not legal comes first, the weather problem second', () {
      final r = go('KDLH', report: legal()); // no entries, passengers off
      // Passengers off and medical/review valid: legal, so make it illegal:
      expect(r.verdict, isNot(GoVerdict.notLegal));
      final illegal = evaluateGo(
        legal: const LegalityEngine().evaluate(
          entries: const [],
          profile: legalProfile,
          flight: PlannedFlight(
              date: DateTime(2026, 10, 14),
              categoryClass: 'ASEL',
              passengers: true),
        ),
        weather: snap('KDLH'),
        minimums: const PersonalMinimums(day: limits),
        departureLocal: DateTime.utc(2026, 10, 14, 13, 30),
        now: capturedAt('metar_KDLH'),
      );
      expect(illegal.verdict, GoVerdict.notLegal);
      expect(illegal.headline, 'Not legal: passenger currency not on record');
      expect(illegal.secondLine,
          'Outside your minimums: ceiling 1300 ft < your 2000 ft');
    });

    test('a stale METAR is flagged and not treated as current (KPAO)', () {
      final r = go('KPAO');
      expect(r.metarStale, isTrue);
      expect(r.verdict, GoVerdict.incomplete);
      expect(r.headline, contains('9 h 16 min old'));
    });

    test('minimums not set: legal, weather not checked against them', () {
      final r = go('KSJC', set: MinimumsSet.blank);
      expect(r.verdict, GoVerdict.incomplete);
      expect(r.headline, contains('day minimums are not set'));
    });

    test('night flight uses the night set', () {
      final r = evaluateGo(
        legal: legal(night: true),
        weather: snap('KSJC'),
        minimums: const PersonalMinimums(
            day: limits, night: MinimumsSet(ceilingFt: 50000)),
        departureLocal: DateTime.utc(2026, 10, 14, 13, 30),
        now: capturedAt('metar_KSJC'),
      );
      // KSJC reports no ceiling at all, which passes any ceiling limit.
      expect(r.verdict, GoVerdict.inside);
      expect(r.metarCheck!.lines.first.limit, '≥ 50000 ft');
    });

    test('TAF groups within departure ±1 h are checked (KDLH base BKN010)',
        () {
      final r = go('KDLH',
          departure: DateTime.utc(2026, 10, 14, 12, 30),
          set: const MinimumsSet(ceilingFt: 1200));
      expect(r.tafChecks.map((t) => t.source),
          ['TAF Base 12:00Z–14:00Z']);
      final ceil = r.tafChecks.single.lines.first;
      expect(ceil.observed, 'BKN 1000 ft');
      expect(ceil.state, CheckState.outside);
      // METAR OVC013 is inside 1200, so the TAF line sets the headline.
      expect(r.headline,
          'Outside your minimums: ceiling 1000 ft < your 1200 ft (TAF Base 12:00Z–14:00Z)');
    });

    test('a departure on a TAF boundary checks both groups (KSJC 19Z)', () {
      final r = go('KSJC', departure: DateTime.utc(2026, 10, 14, 18, 30));
      expect(r.tafChecks, hasLength(2));
    });

    test('no TAF issued says so (KPAO)', () {
      final r = go('KPAO');
      expect(r.tafChecks, isEmpty);
      expect(r.tafNote, 'No TAF is issued for KPAO.');
    });

    test('a departure outside the TAF says so', () {
      final r = go('KSJC', departure: DateTime.utc(2026, 10, 20, 12));
      expect(r.tafNote, 'The TAF does not cover departure ±1 h.');
    });

    test('offline: legal section still decides, weather says why', () {
      final r = evaluateGo(
        legal: legal(),
        weather: WeatherSnapshot(
          station: 'KPAO',
          metarStatus: FetchStatus.offline,
          tafStatus: FetchStatus.offline,
          airportStatus: FetchStatus.offline,
          fetchedAt: DateTime.utc(2026, 10, 14),
        ),
        minimums: const PersonalMinimums(day: limits),
        departureLocal: DateTime.utc(2026, 10, 14, 13),
        now: DateTime.utc(2026, 10, 14, 13),
      );
      expect(r.verdict, GoVerdict.incomplete);
      expect(r.headline, contains('Could not reach aviationweather.gov'));
      expect(r.tafNote, 'TAF not fetched: offline.');
    });

    test('204 "no such station" has its own copy', () {
      final s = WeatherSnapshot(
        station: 'KZZZ',
        metarStatus: FetchStatus.noData,
        tafStatus: FetchStatus.noData,
        airportStatus: FetchStatus.noData,
        fetchedAt: DateTime.utc(2026, 10, 14),
      );
      expect(s.metarProblem, contains('has no current METAR for KZZZ'));
    });

    test('a server error has its own copy', () {
      final s = WeatherSnapshot(
        station: 'KPAO',
        metarStatus: FetchStatus.failed,
        tafStatus: FetchStatus.failed,
        airportStatus: FetchStatus.failed,
        fetchedAt: DateTime.utc(2026, 10, 14),
      );
      expect(s.metarProblem, contains('answered with an error'));
    });

    test('every result carries the decision line', () {
      expect(GoResult.disclaimer,
          "Your decision, not the app's. Check an official briefing "
          '(1800wxbrief.com) before flight.');
    });
  });
}
