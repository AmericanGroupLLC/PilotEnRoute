/// Screens for spec S1-S3 and the Kit explanations: the student progress card
/// and screen, "Paste CSV", the Go Card night-currency window, and the
/// "About" sheet on each Kit tool.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/logbook/logbook_csv.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/screens/plan_screen.dart';
import 'package:pilot_enroute/screens/logbook_screen.dart';
import 'package:pilot_enroute/screens/student_progress_screen.dart';
import 'package:pilot_enroute/screens/today_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';

import '../support/awc_fixtures.dart';
import '../support/harness.dart';

LogbookEntry lesson(int day, {double dual = 1.2, double solo = 0}) =>
    LogbookEntry(
      date: DateTime(2026, 10, day),
      aircraftType: 'C172',
      tailNumber: 'N35AB',
      from: 'KPAO',
      to: 'KPAO',
      totalTime: dual + solo,
      categoryClass: 'ASEL',
      dualReceived: dual,
      soloTime: solo,
      dayTakeoffs: 3,
      dayLandings: 3,
    );

void big(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
}

Future<Harness> openLogbook(WidgetTester tester, List<LogbookEntry> seed,
    {bool student = false}) async {
  big(tester);
  final h = Harness(
    settings: SettingsStore(
        onboardingDone: true,
        profile: PilotProfile(studentPilot: student)),
    logbook: LogbookService(store: MemoryLogbookStore(seed)),
  );
  await h.logbook.init();
  await tester.pumpWidget(
      h.wrap(LogbookScreen(clock: () => DateTime(2026, 10, 17, 12))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

void mockClipboard(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  group('S1 student progress', () {
    testWidgets('Totals shows the progress card only to a student',
        (tester) async {
      await openLogbook(tester, [lesson(3)], student: false);
      await tester.tap(find.text('Totals'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('student-progress-card')), findsNothing);
    });

    testWidgets('a student opens it from Totals and sees real numbers',
        (tester) async {
      await openLogbook(
          tester, [lesson(3), lesson(5), lesson(9, dual: 0, solo: 1.0)],
          student: true);
      await tester.tap(find.text('Totals'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('student-progress-card')));
      await tester.pumpAndSettle();
      expect(find.text('Private pilot progress'), findsOneWidget);
      // 2.4 dual + 1.0 solo.
      expect(find.text('61.109(a) · 3.4 of 40.0 h'), findsOneWidget);
      expect(find.text('61.109(a) · 2.4 of 20.0 h'), findsOneWidget);
      expect(find.textContaining('does not record this'), findsNWidgets(3));
      expect(find.text('CHECK'), findsNWidgets(3));
      expect(find.textContaining('does not by itself make you eligible'),
          findsOneWidget);
    });

    testWidgets('an empty logbook shows the honest empty state',
        (tester) async {
      big(tester);
      final h = Harness();
      await tester.pumpWidget(h.wrap(const StudentProgressScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No flights logged yet'), findsOneWidget);
      expect(find.text('MET'), findsNothing);
    });
  });

  group('S3 Paste CSV', () {
    testWidgets('pasting an export adds the new flights and skips the rest',
        (tester) async {
      final existing = lesson(3);
      final csv = logbookToCsv([existing, lesson(5), lesson(7)]);
      mockClipboard(tester, csv);
      final h = await openLogbook(tester, [existing]);
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste CSV'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paste-csv-dialog')), findsOneWidget);
      expect(find.text('2 flights to add.'), findsOneWidget);
      expect(find.text('1 already in your logbook (skipped).'), findsOneWidget);
      await tester.tap(find.text('Add 2'));
      await tester.pumpAndSettle();
      expect(h.logbook.entries, hasLength(3));
      expect(find.text('Added 2 flights from CSV'), findsOneWidget);
    });

    testWidgets('a foreign CSV is refused without a dialog', (tester) async {
      mockClipboard(tester, 'Date,Aircraft ID,Total Time\n2026-10-01,N1,1.0\n');
      final h = await openLogbook(tester, const []);
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste CSV'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paste-csv-dialog')), findsNothing);
      expect(find.textContaining('This is not a PilotEnRoute logbook CSV'),
          findsOneWidget);
      expect(h.logbook.entries, isEmpty);
    });

    testWidgets('Cancel adds nothing', (tester) async {
      mockClipboard(tester, logbookToCsv([lesson(5)]));
      final h = await openLogbook(tester, const []);
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.logbook.entries, isEmpty);
    });
  });

  group('S2 night window on the Go Card', () {
    Future<void> openToday(WidgetTester tester) async {
      big(tester);
      final h = Harness(
        settings: SettingsStore(onboardingDone: true, homeAirport: 'KACK'),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(h.wrap(
            TodayScreen(clock: () => DateTime.utc(2026, 10, 14, 13, 10))));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }, () => awcClient());
    }

    testWidgets('hidden until Night is on', (tester) async {
      await openToday(tester);
      expect(find.byKey(const Key('go-night-window')), findsNothing);
    });

    testWidgets('Night on: the window at KACK from the checked airport '
        'position, in Zulu', (tester) async {
      await openToday(tester);
      await tester.tap(find.text('Night'));
      await tester.pump();
      final line = find.byKey(const Key('go-night-window'));
      expect(line, findsOneWidget);
      expect(
          find.descendant(
              of: line,
              matching: find.textContaining(
                  'Night for passenger currency (61.57(b)) at KACK, evening '
                  'of')),
          findsOneWidget);
      expect(
          find.descendant(
              of: line, matching: find.textContaining(RegExp(r'about \d\d:\d\dZ'))),
          findsOneWidget);
    });
  });

  group('Kit explanations', () {
    test('every Kit tool has an explanation', () {
      for (final t in PlanScreen.tools) {
        expect(PlanScreen.explanations[t.$1], isNotNull, reason: t.$1);
        expect(PlanScreen.explanations[t.$1]!.length, greaterThan(80));
      }
    });

    test('safety wording points back to the POH/AFM and official sources', () {
      expect(PlanScreen.explanations['/checklist'], contains('POH/AFM'));
      expect(PlanScreen.explanations['/fuel'], contains('91.151'));
      expect(PlanScreen.explanations['/documents'],
          contains('does not replace a document'));
    });

    testWidgets('the info button opens the sheet for that tool',
        (tester) async {
      big(tester);
      await tester.pumpWidget(Harness().wrap(const PlanScreen()));
      await tester.tap(find.byTooltip('About E6B'));
      await tester.pumpAndSettle();
      expect(find.text('About E6B'), findsOneWidget);
      expect(find.textContaining('wind triangle'), findsOneWidget);
    });
  });
}
