/// Foldable / dual-screen layout tests.
///
/// The defining property of a folding phone is not one extra screen size — it
/// is that the window *changes size while the app is running*, and that it
/// takes aspect ratios no current iPhone has: near-square when unfolded, very
/// tall and narrow when folded. A layout that only ever sees 9:19.5 breaks
/// visibly the first time the user unfolds the device.
///
/// Apple ships no simulator for this, so these widget tests are the
/// verification. Each primary screen is pumped at the folded, unfolded,
/// landscape and mid-resize geometries and must produce no RenderFlex
/// overflow and no layout exception. The busiest screen is also pumped at a
/// 1.6x text scale, because a fold plus large type is where text layouts
/// actually break.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/content/faa_questions.g.dart';
import 'package:pilot_enroute/screens/airport_ops_screen.dart';
import 'package:pilot_enroute/screens/airport_screen.dart';
import 'package:pilot_enroute/screens/app_shell.dart';
import 'package:pilot_enroute/screens/checklist_screen.dart';
import 'package:pilot_enroute/screens/documents_screen.dart';
import 'package:pilot_enroute/screens/e6b_screen.dart';
import 'package:pilot_enroute/screens/flight_plan_screen.dart';
import 'package:pilot_enroute/screens/fuel_screen.dart';
import 'package:pilot_enroute/screens/go_history_screen.dart';
import 'package:pilot_enroute/screens/home_screen.dart';
import 'package:pilot_enroute/screens/learn_screen.dart';
import 'package:pilot_enroute/screens/library_screen.dart';
import 'package:pilot_enroute/screens/plan_screen.dart';
import 'package:pilot_enroute/screens/logbook_entry_screen.dart';
import 'package:pilot_enroute/screens/logbook_screen.dart';
import 'package:pilot_enroute/screens/minimums_screen.dart';
import 'package:pilot_enroute/screens/onboarding_screen.dart';
import 'package:pilot_enroute/screens/practice_screen.dart';
import 'package:pilot_enroute/screens/quiz_screen.dart';
import 'package:pilot_enroute/screens/reminders_screen.dart';
import 'package:pilot_enroute/screens/settings_screen.dart';
import 'package:pilot_enroute/screens/six_pack_screen.dart';
import 'package:pilot_enroute/screens/today_screen.dart';
import 'package:pilot_enroute/screens/weather_screen.dart';
import 'package:pilot_enroute/screens/weight_balance_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';

import 'support/harness.dart';

/// The geometries a folding iPhone actually presents, in logical pixels.
///
/// `folded` is the cover display: taller and narrower than any current phone.
/// `unfolded` is near-square (aspect ~0.87), which no iPhone has today.
/// `midResize` is a frame caught part-way through the unfold animation — the
/// framework really does lay out at those in-between widths.
const Map<String, Size> _foldGeometries = <String, Size>{
  'folded cover 360x840': Size(360, 840),
  'unfolded near-square 730x840': Size(730, 840),
  'unfolded landscape 840x730': Size(840, 730),
  'mid-resize 540x840': Size(540, 840),
  'smallest supported 320x690': Size(320, 690),
  // The same device turned on its side. A folded phone in landscape is the
  // shortest window the app will ever get.
  'folded landscape 840x360': Size(840, 360),
  'mid-resize landscape 840x540': Size(840, 540),
};

/// A logbook with real-looking rows the pilot would have typed, so the
/// ledger and Today layouts are exercised with content, not just empty
/// states. (Test data only; the app never seeds entries.)
LogbookService _seeded() => LogbookService(
      store: MemoryLogbookStore([
        for (var i = 0; i < 8; i++)
          LogbookEntry(
            date: DateTime(2026, 10, 12 - i),
            aircraftType: 'C172S',
            tailNumber: 'N35${i}2X',
            from: 'KPAO',
            to: 'KSQL',
            totalTime: 1.2,
            categoryClass: 'ASEL',
            dayTakeoffs: 2,
            dayLandings: 2,
            remarks: 'Pattern work, crosswind practice on 31',
          ),
      ]),
    );

Widget _wrap(Widget screen, {double textScale = 1.0}) {
  return Harness(
    settings: SettingsStore(onboardingDone: true, homeAirport: ''),
    logbook: _seeded(),
  ).wrap(screen, textScale: textScale);
}

/// Pumps until the tree is quiet.
///
/// `pumpAndSettle` alone cannot be used across the whole app: a screen that
/// drives a controller with `..repeat()` never settles. A
/// timeout there is not a layout failure, so it is swallowed — any real
/// build/layout exception is still recorded by the binding and is picked up by
/// `takeException()` below.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.paint,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Pumps [screen] at [size] and fails if the frame produced any exception.
/// RenderFlex overflow errors surface through `takeException()`.
Future<void> _expectNoOverflow(
  WidgetTester tester,
  Size size,
  String label,
  Widget screen, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(screen, textScale: textScale));
  await _settle(tester);

  expect(
    tester.takeException(),
    isNull,
    reason: '${screen.runtimeType} overflowed at $label '
        '(${size.width.toInt()}x${size.height.toInt()}, '
        'textScale ${textScale}x)',
  );
}

/// Registers the whole fold sweep for one screen.
void _foldSweep(String name, Widget Function() build) {
  group(name, () {
    _foldGeometries.forEach((label, size) {
      testWidgets('lays out at $label', (tester) async {
        await _expectNoOverflow(tester, size, label, build());
      });
    });
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('every primary screen survives a fold', () {
    _foldSweep('TodayScreen', () => const TodayScreen());
    _foldSweep('LogbookScreen', () => const LogbookScreen());
    _foldSweep('LogbookEntryScreen', () => const LogbookEntryScreen());
    _foldSweep('WeatherScreen', () => const WeatherScreen());
    _foldSweep('PlanScreen', () => const PlanScreen());
    _foldSweep('AirportScreen', () => const AirportScreen());
    _foldSweep('SettingsScreen', () => SettingsScreen(
        isPrivacyOptionsRequired: () async => true,
        showPrivacyOptions: () async {}));
    _foldSweep('MinimumsScreen', () => const MinimumsScreen());
    _foldSweep('RemindersScreen', () => const RemindersScreen());
    _foldSweep('GoHistoryScreen', () => const GoHistoryScreen());
    _foldSweep('OnboardingScreen', () => const OnboardingScreen());
    _foldSweep('ChecklistScreen', () => const ChecklistScreen());
    _foldSweep('DocumentsScreen', () => const DocumentsScreen());
    _foldSweep('FlightPlanScreen', () => const FlightPlanScreen());
    _foldSweep('E6BScreen', () => const E6BScreen());
    _foldSweep('FuelScreen', () => const FuelScreen());
    _foldSweep('WeightBalanceScreen', () => const WeightBalanceScreen());
    _foldSweep('HomeScreen', () => const HomeScreen());
    _foldSweep('LearnScreen', () => const LearnScreen());
    _foldSweep('PracticeScreen', () => const PracticeScreen());
    _foldSweep('LibraryScreen', () => const LibraryScreen());
    _foldSweep('SixPackScreen', () => const SixPackScreen());
    _foldSweep('AirportOpsScreen', () => const AirportOpsScreen());
    _foldSweep('QuizScreen', () => QuizScreen(
        title: 'All questions', questions: faaSampleQuestions.take(3).toList()));
  });

  // A fold plus large type is where text layouts actually break: the window
  // gets narrower *and* every string gets longer at the same time.
  group('large type on a folded window', () {
    final busiest = <String, Widget Function()>{
      'TodayScreen': () => const TodayScreen(),
      'LogbookScreen': () => const LogbookScreen(),
      'LogbookEntryScreen': () => const LogbookEntryScreen(),
      'OnboardingScreen': () => const OnboardingScreen(),
      'MinimumsScreen': () => const MinimumsScreen(),
      'E6BScreen': () => const E6BScreen(),
      'WeightBalanceScreen': () => const WeightBalanceScreen(),
      'HomeScreen': () => const HomeScreen(),
      'PracticeScreen': () => const PracticeScreen(),
      'SixPackScreen': () => const SixPackScreen(),
      'QuizScreen': () => QuizScreen(
          title: 'All questions',
          questions: faaSampleQuestions.take(3).toList()),
    };

    busiest.forEach((name, build) {
      _foldGeometries.forEach((label, size) {
        testWidgets('$name at $label, 1.6x text', (tester) async {
          await _expectNoOverflow(tester, size, label, build(),
              textScale: 1.6);
        });
      });
    });
  });

  // The single most common foldable bug: a breakpoint read once at startup
  // does not update when the device unfolds. Resizing the same live tree
  // (rather than pumping a fresh one) is what catches it.
  group('resizing a live tree', () {
    testWidgets('the app shell reflows from folded to unfolded and back',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 840);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const AppShell()));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'folded');

      for (final size in const [
        Size(540, 840),
        Size(730, 840),
        Size(840, 730),
        Size(320, 690),
        Size(360, 840),
      ]) {
        tester.view.physicalSize = size;
        await _settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'AppShell overflowed after resizing to '
              '${size.width.toInt()}x${size.height.toInt()}',
        );
      }
    });
  });
}
