/// The Go Card on Today, driven by a fake HTTP client serving recorded real
/// aviationweather.gov answers (captured 2026-10-14T13:03:13Z) and a seeded
/// logbook. Asserts the exact crosswind number and the lapse dates shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/minimums/go_check.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/screens/logbook_entry_screen.dart';
import 'package:pilot_enroute/screens/today_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:pilot_enroute/widgets/ad_banner_widget.dart';

import '../support/awc_fixtures.dart';
import '../support/harness.dart';

DateTime clock() => DateTime.utc(2026, 10, 14, 13, 10);

final profile = PilotProfile(
  medicalKind: MedicalKind.third,
  medicalExamDate: DateTime(2025, 3, 10),
  age40OrOlderAtExam: true,
  flightReviewDate: DateTime(2025, 2, 3),
  homeCategoryClass: 'ASEL',
);

LogbookEntry flight(DateTime d, {int to = 3, int ldg = 3}) => LogbookEntry(
      date: d,
      aircraftType: 'C172',
      tailNumber: 'N35AB',
      from: 'KACK',
      to: 'KACK',
      totalTime: 1.2,
      categoryClass: 'ASEL',
      dayTakeoffs: to,
      dayLandings: ldg,
    );

Future<Harness> openToday(
  WidgetTester tester, {
  String home = 'KACK',
  List<LogbookEntry> entries = const [],
  PersonalMinimums minimums =
      const PersonalMinimums(day: MinimumsSet(maxCrosswindKt: 5)),
  http.Client Function()? client,
}) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final h = Harness(
    settings: SettingsStore(
        onboardingDone: true,
        homeAirport: home,
        profile: profile,
        minimums: minimums),
    logbook: LogbookService(store: MemoryLogbookStore(entries)),
  );
  await http.runWithClient(() async {
    await tester.pumpWidget(h.wrap(const TodayScreen(clock: clock)));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }, client ?? awcClient);
  return h;
}

void main() {
  testWidgets('KACK 240/15G23 with a 5 kt limit: the card says crosswind 6 kt '
      'on 24, and shows the passenger lapse date', (tester) async {
    final h = await openToday(tester, entries: [flight(DateTime(2026, 10, 1))]);

    expect(
        find.text('Outside your minimums: crosswind 6 kt on 24 > your 5 kt'),
        findsOneWidget);
    expect(find.text('4 kt, gust 6 kt on 24'), findsOneWidget);
    expect(find.textContaining('Runway 24 (225° true): headwind 14 kt'),
        findsOneWidget);
    expect(find.text('METAR KACK 141253Z 24015G23KT 7SM CLR 19/17 A2982 RMK '
            'AO2 SLP097 T01940172'),
        findsOneWidget);
    // Legal, from the seeded flight: 1 Oct + 90 days.
    expect(find.text('Valid through 30 Dec 2026'), findsOneWidget);
    expect(find.text('Third-class medical: valid through 31 Mar 2027'),
        findsOneWidget);
    expect(find.text('Valid through 28 Feb 2027'), findsOneWidget);
    expect(find.text(GoResult.disclaimer), findsOneWidget);
    // The check went to history.
    expect(h.logbook.checks.single.departure, 'KACK');
    expect(h.logbook.checks.single.verdict, GoVerdict.outside);
  });

  testWidgets('inside every limit reads "Inside your minimums and legal"',
      (tester) async {
    await openToday(tester,
        entries: [flight(DateTime(2026, 10, 1))],
        minimums: const PersonalMinimums(
            day: MinimumsSet(
                // Wide enough that every KACK TAF group near departure is
                // inside too, whatever time zone the test machine is in.
                ceilingFt: 1000,
                visibilitySm: 3,
                maxWindKt: 20,
                maxGustKt: 30,
                maxCrosswindKt: 20)));
    expect(find.text('Inside your minimums and legal for this flight'),
        findsOneWidget);
    expect(find.textContaining('safe'), findsNothing);
  });

  testWidgets('a fresh install shows the honest empty state', (tester) async {
    await openToday(tester);
    expect(
        find.text("No flights logged yet. Log your recent flights and this "
            "shows what you're current for."),
        findsOneWidget);
    expect(find.text('Nothing logged that counts yet'), findsWidgets);
  });

  testWidgets('passengers on with no flights: not legal, worded', (tester) async {
    await openToday(tester);
    await tester.tap(find.text('Passengers'));
    await tester.pump();
    expect(find.text('Not legal: passenger currency not on record'),
        findsOneWidget);
  });

  testWidgets('no minimums set: the app asks, never suggests', (tester) async {
    await openToday(tester, minimums: PersonalMinimums.blank);
    expect(find.textContaining('minimums are not set'), findsWidgets);
    expect(find.text('Set my minimums'), findsOneWidget);
  });

  testWidgets('offline: legal still works, weather says it could not fetch',
      (tester) async {
    await openToday(tester,
        entries: [flight(DateTime(2026, 10, 1))],
        client: () => awcClient(offline: {'metar', 'taf', 'airport'}));
    expect(find.textContaining('Could not reach aviationweather.gov'),
        findsWidgets);
    expect(find.text('Valid through 30 Dec 2026'), findsOneWidget);
  });

  testWidgets('an unknown station (204) has its own copy', (tester) async {
    await openToday(tester, home: 'KZZZ');
    expect(find.textContaining('has no current METAR for KZZZ'), findsWidgets);
  });

  testWidgets('a stale METAR is tagged (KPAO, 9 h old at capture)',
      (tester) async {
    await openToday(tester, home: 'KPAO');
    expect(find.text('STALE'), findsOneWidget);
    expect(find.textContaining('9 h 23 min old'), findsOneWidget);
    expect(find.text('No TAF is issued for KPAO.'), findsOneWidget);
  });

  testWidgets('"Log this flight" opens the entry form pre-filled',
      (tester) async {
    await openToday(tester);
    await tester.enterText(find.byKey(const Key('go-destination')), 'kmvy');
    await tester.tap(find.text('Night'));
    await tester.pump();
    await tester.ensureVisible(find.text('Log this flight'));
    await tester.tap(find.text('Log this flight'));
    await tester.pumpAndSettle();
    expect(find.byType(LogbookEntryScreen), findsOneWidget);
    final from = tester.widget<TextFormField>(find.byKey(const Key('entry-from')));
    final to = tester.widget<TextFormField>(find.byKey(const Key('entry-to')));
    expect(from.controller!.text, 'KACK');
    expect(to.controller!.text, 'KMVY');
    final night = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Night flight'));
    expect(night.value, isTrue);
  });

  testWidgets('no ad anywhere on Today or the result', (tester) async {
    await openToday(tester, entries: [flight(DateTime(2026, 10, 1))]);
    expect(find.byType(AdBannerWidget), findsNothing);
  });
}
