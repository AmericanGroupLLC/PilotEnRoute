// BESPOKE screenshots for PilotEnRoute - do not regenerate.
//
// Drives the real app from a fresh install, through the real UI: the
// three-screen onboarding (no account), Today's Go Card on live
// aviationweather.gov data, the logbook entry form, the logbook with a
// search, Weather and Kit.
//
// Everything shown is entered through the UI in this run: the home airport,
// the medical and flight-review dates (today's date from the date picker),
// the personal minimums, and the one flight logged from the Go Card. Nothing
// is seeded. The METAR/TAF is whatever AWC reports at the time of the run,
// so the Go Card result is real and not staged.
//
// No ad can appear: Today, the Go Card and the entry form carry none, and the
// Logbook's in-list slot only exists after its 5th row (this run logs one).
// The Weather tab's slot is scrolled past in a debug build only if present;
// a "Test Ad" must never reach a store screenshot, so build with
// --dart-define=SCREENSHOT=true, which requests no ad at all.
//
// Run:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart \
//     --dart-define=SCREENSHOT=true -d <simulator>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pilot_enroute/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps real frames until [f] matches, or [timeout] elapses.
  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder f, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      if (f.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    return f.evaluate().isNotEmpty;
  }

  Future<void> waitFor(WidgetTester tester, Finder f, String what,
      {Duration timeout = const Duration(seconds: 25)}) async {
    if (!await pumpUntil(tester, f, timeout: timeout)) {
      fail('[shots] Timed out after ${timeout.inSeconds}s waiting for $what '
          '(${f.describeMatch(Plurality.many)}).');
    }
  }

  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    } catch (_) {
      // Something animates indefinitely; the real frames below cover it.
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
  }

  var surfaceConverted = false;

  Future<void> shot(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (final m in tester
        .stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      m.clearSnackBars();
    }
    await settle(tester);
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
    debugPrint('[shots] captured $name');
  }

  /// Scrolls the page's main vertical list until [f] is built and on screen.
  /// Lists build lazily, so a widget far down does not exist until then.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      final list = find
          .byWidgetPredicate((w) =>
              w is Scrollable && w.axisDirection == AxisDirection.down)
          .hitTestable()
          .first;
      await tester.scrollUntilVisible(f, 250, scrollable: list);
    }
    await tester.ensureVisible(f);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await reveal(tester, f);
    await waitFor(tester, f, key);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> typeKey(WidgetTester tester, String key, String text) async {
    final f = find.byKey(Key(key));
    await reveal(tester, f);
    await waitFor(tester, f, key);
    await tester.enterText(f, text);
    await tester.pump();
  }

  /// Opens a date picker with [key] and accepts its default (today).
  Future<void> pickToday(WidgetTester tester, String key) async {
    await tapKey(tester, key);
    final ok = find.text('OK');
    await waitFor(tester, ok, 'the date picker');
    await tester.tap(ok);
    await settle(tester);
  }

  testWidgets('screenshots', (WidgetTester tester) async {
    app.main();
    await waitFor(tester, find.byKey(const Key('onboarding-airport')),
        'onboarding', timeout: const Duration(seconds: 120));

    // ── 1: home airport and class.
    await typeKey(tester, 'onboarding-airport', 'KPAO');
    await tapKey(tester, 'class-ASEL');
    await shot(tester, '01_onboarding_airport');
    await tapKey(tester, 'onboarding-next-1');

    // ── 2: medical and flight review, entered with the date pickers.
    await tapKey(tester, 'medical-third');
    await pickToday(tester, 'medical-exam-date');
    await tapKey(tester, 'age-under40');
    await pickToday(tester, 'flight-review-date');
    await tapKey(tester, 'onboarding-next-2');

    // ── 3: personal minimums, typed in.
    await typeKey(tester, 'min-day-ceilingFt', '2000');
    await typeKey(tester, 'min-day-visibilitySm', '5');
    await typeKey(tester, 'min-day-maxWindKt', '20');
    await typeKey(tester, 'min-day-maxGustKt', '25');
    await typeKey(tester, 'min-day-maxCrosswindKt', '10');
    await shot(tester, '02_onboarding_minimums');
    await tapKey(tester, 'onboarding-finish');

    // ── Today: the Go Card fetches KPAO from aviationweather.gov.
    await waitFor(tester, find.byKey(const Key('go-verdict')), 'the Go Card',
        timeout: const Duration(seconds: 40));
    await pumpUntil(tester, find.text('Check again'));
    await settle(tester);
    await shot(tester, '03_go_card');

    // ── Log this flight, from the Go Card.
    final logIt = find.text('Log this flight');
    await reveal(tester, logIt);
    await tester.tap(logIt);
    await settle(tester);
    await typeKey(tester, 'entry-type', 'C172S');
    await typeKey(tester, 'entry-tail', 'N35AB');
    await typeKey(tester, 'entry-total', '1.2');
    await typeKey(tester, 'entry-pic', '1.2');
    await typeKey(tester, 'entry-dayTo', '3');
    await typeKey(tester, 'entry-dayLdg', '3');
    await shot(tester, '04_entry_form');
    await typeKey(tester, 'entry-remarks', 'Pattern work');
    await tapKey(tester, 'entry-save');

    // ── Logbook with a search.
    await tester.tap(find.text('Logbook').last);
    await settle(tester);
    await typeKey(tester, 'logbook-search', 'KPAO');
    await shot(tester, '05_logbook_search');

    // ── Weather.
    await tester.tap(find.text('Weather').last);
    await settle(tester);
    await pumpUntil(tester, find.textContaining('METAR KPAO'),
        timeout: const Duration(seconds: 30));
    await shot(tester, '06_weather');

    // ── Kit.
    await tester.tap(find.text('Kit').last);
    await settle(tester);
    await shot(tester, '07_kit');
  });
}
