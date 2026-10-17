/// The Clear Skies 5-tab screens: Home from the pilot's own data, the Plan
/// hub, and Learn's library, six-pack trainer and airport operations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/screens/airport_ops_screen.dart';
import 'package:pilot_enroute/screens/home_screen.dart';
import 'package:pilot_enroute/screens/learn_screen.dart';
import 'package:pilot_enroute/screens/library_screen.dart';
import 'package:pilot_enroute/screens/plan_screen.dart';
import 'package:pilot_enroute/screens/six_pack_screen.dart';
import 'package:pilot_enroute/screens/today_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/practice_store.dart';
import 'package:pilot_enroute/services/settings_store.dart';

import '../support/awc_fixtures.dart';
import '../support/harness.dart';

final now = DateTime(2026, 10, 17, 12);

final legalProfile = PilotProfile(
  medicalKind: MedicalKind.third,
  medicalExamDate: DateTime(2026, 1, 10),
  age40OrOlderAtExam: false,
  flightReviewDate: DateTime(2026, 1, 10),
  homeCategoryClass: 'ASEL',
);

LogbookEntry flight(int day) => LogbookEntry(
      date: DateTime(2026, 10, day),
      aircraftType: 'C172',
      tailNumber: 'N35AB',
      from: 'KPAO',
      to: 'KSQL',
      totalTime: 1.2,
      categoryClass: 'ASEL',
      dayTakeoffs: 1,
      dayLandings: 1,
    );

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
}

Future<Harness> openHome(WidgetTester tester,
    {PilotProfile profile = PilotProfile.empty,
    List<LogbookEntry> entries = const [],
    PracticeStore? practice}) async {
  tall(tester);
  final h = Harness(
    settings: SettingsStore(
        onboardingDone: true, homeAirport: 'KPAO', profile: profile),
    logbook: LogbookService(store: MemoryLogbookStore(entries)),
    practice: practice,
  );
  await h.logbook.init();
  await tester.pumpWidget(h.wrap(HomeScreen(clock: () => now)));
  await tester.pump();
  return h;
}

void main() {
  group('Home', () {
    testWidgets('nothing on record: NOT LEGAL with the reason, empty logbook '
        'line, no readiness yet', (tester) async {
      await openHome(tester,
          profile: const PilotProfile(homeCategoryClass: 'ASEL'));
      expect(find.text('Go Card · KPAO'), findsOneWidget);
      expect(find.text('Not legal: flight review not on record'),
          findsOneWidget);
      expect(find.text('NOT LEGAL'), findsOneWidget);
      expect(find.text('No flights logged yet'), findsOneWidget);
      expect(find.text('FAA sample questions, each answer shown in FAA text'),
          findsOneWidget);
      expect(find.byKey(const Key('home-student-progress')), findsNothing);
    });

    testWidgets('medical and flight review on record: LEGAL, and the last '
        'flight from the logbook', (tester) async {
      await openHome(tester,
          profile: legalProfile, entries: [flight(3), flight(12), flight(8)]);
      expect(find.text('LEGAL'), findsOneWidget);
      expect(find.text('Legal to fly today. Check the weather next.'),
          findsOneWidget);
      expect(find.text('Last logged: KPAO → KSQL · 12 Oct'), findsOneWidget);
    });

    testWidgets('a student sees 61.109(a) progress', (tester) async {
      await openHome(tester,
          profile: const PilotProfile(
              studentPilot: true, homeCategoryClass: 'ASEL'));
      expect(find.byKey(const Key('home-student-progress')), findsOneWidget);
      expect(find.textContaining('61.109(a) · 0 of 11 tracked items met'),
          findsOneWidget);
    });

    testWidgets('readiness from the pilot\'s own answers', (tester) async {
      final p = PracticeStore(answers: [
        for (var i = 0; i < 10; i++)
          PracticeAnswer(
              questionId: 'PAR-$i',
              topic: 'airspace',
              correct: i < 8,
              at: now),
      ]);
      await openHome(tester, practice: p);
      expect(find.text('First try: 80% of 10 questions · goal 85–90%'),
          findsOneWidget);
    });

    testWidgets('no word "safe" anywhere on Home', (tester) async {
      await openHome(tester, profile: legalProfile, entries: [flight(12)]);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
      for (final t in texts) {
        expect(t.toLowerCase(), isNot(contains('safe')), reason: t);
      }
    });
  });

  group('Plan', () {
    testWidgets('Go Card, Weather, Charts and history tiles, then the flight '
        'bag without a second Charts row', (tester) async {
      tall(tester);
      await tester.pumpWidget(Harness().wrap(const PlanScreen()));
      for (final t in PlanScreen.hubTiles) {
        expect(find.byKey(Key('plan-tile-${t.$1}')), findsOneWidget);
      }
      expect(find.text('Charts & plates'), findsOneWidget);
      expect(find.text('E6B'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('Learn', () {
    testWidgets('three ground-school entries', (tester) async {
      tall(tester);
      await tester.pumpWidget(Harness().wrap(const LearnScreen()));
      expect(find.byKey(const Key('learn-library')), findsOneWidget);
      expect(find.byKey(const Key('learn-sixpack')), findsOneWidget);
      expect(find.byKey(const Key('learn-airport-ops')), findsOneWidget);
    });

    testWidgets('library: PHAK opens by chapter on faa.gov', (tester) async {
      tall(tester);
      final opened = <Uri>[];
      await tester.pumpWidget(Harness().wrap(LibraryScreen(opener: (u) async {
        opened.add(u);
        return true;
      })));
      await tester.tap(find.byKey(const Key('library-phak')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-phak-8')));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'www.faa.gov');
      expect(opened.single.path, endsWith('.pdf'));
    });

    testWidgets('library: a failed open says so', (tester) async {
      tall(tester);
      await tester.pumpWidget(Harness()
          .wrap(LibraryScreen(opener: (u) async => false)));
      await tester.tap(find.byKey(const Key('library-aim')));
      await tester.pumpAndSettle();
      expect(find.text('Could not open www.faa.gov'), findsOneWidget);
    });

    testWidgets('six-pack: tap the altimeter, read PHAK-cited lines, move the '
        'slider', (tester) async {
      tall(tester);
      await tester.pumpWidget(Harness().wrap(const SixPackScreen()));
      expect(find.byKey(const Key('sixpack-lesson-asi')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sixpack-alt')));
      await tester.pump();
      expect(find.byKey(const Key('sixpack-lesson-alt')), findsOneWidget);
      expect(find.textContaining('LOOK OUT BELOW'), findsWidgets);
      expect(find.textContaining('PHAK FAA-H-8083-25C, ch. 8'), findsWidgets);
      expect(find.text('3500 ft'), findsOneWidget);
      await tester.drag(
          find.byKey(const Key('sixpack-slider-Altitude')), const Offset(200, 0));
      await tester.pump();
      expect(find.text('3500 ft'), findsNothing);
    });

    testWidgets('airport operations: pattern, signs and markings tabs',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(Harness().wrap(const AirportOpsScreen()));
      expect(find.textContaining('Downwind leg'), findsOneWidget);
      await tester.tap(find.text('Signs'));
      await tester.pumpAndSettle();
      expect(find.text('Mandatory instruction sign'), findsOneWidget);
      expect(find.text('White inscription on a red background'), findsOneWidget);
      await tester.tap(find.text('Markings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Runway holding position marking'),
          findsOneWidget);
    });
  });

  group('Go Card as a pushed screen', () {
    testWidgets('opening it again with the same METAR adds no second history '
        'record; asking for a check does', (tester) async {
      tall(tester);
      final h = Harness(
          settings: SettingsStore(onboardingDone: true, homeAirport: 'KACK'));
      await h.logbook.init();
      Future<void> open() => http.runWithClient(() async {
            await tester.pumpWidget(h.wrap(TodayScreen(
                key: UniqueKey(),
                clock: () => DateTime.utc(2026, 10, 14, 13, 10))));
            for (var i = 0; i < 12; i++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
          }, () => awcClient());
      await open();
      expect(h.logbook.checks, hasLength(1));
      await open();
      expect(h.logbook.checks, hasLength(1));
      await http.runWithClient(() async {
        await tester.tap(find.text('Check this flight'));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }, () => awcClient());
      expect(h.logbook.checks, hasLength(2));
    });
  });
}
