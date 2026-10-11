// BESPOKE store screenshots for PilotEnRoute - do not regenerate.
//
// Drives the real app from a fresh install, through the real UI, and captures
// the screens the store listing describes (agl-manifest/store/apps/
// PilotEnRoute.json): live weather, the E6B, the logbook, checklists and the
// FAA education hub.
//
// Sign-in is optional in this app (the listing says so, and LoginScreen offers
// "Continue without signing in"), and none of the screens below needs an
// account, so the test takes that real button. QA_EMAIL / QA_PASSWORD are not
// needed and are not read.
//
// Content is real: the METAR/TAF comes live from the app's weather service,
// the E6B solution is computed by the app from values typed into its fields,
// and the two logbook flights and the ticked checklist items are created
// through the UI and stored only on the device (sqflite / shared_preferences).
//
// Nothing here touches the home screen's AdBannerWidget slots - home is used
// only to navigate - because a debug `flutter drive` build serves Google's
// test units, and a "Test Ad" banner must never reach a store screenshot.
//
// Run by the orchestrator:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart -d <simulator>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pilot_enroute/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps real frames until [f] matches, or [timeout] elapses.
  ///
  /// pumpAndSettle is wrong for waiting on the app: it returns instantly while
  /// main() is still awaiting and nothing is mounted, and it never settles
  /// while a progress indicator spins.
  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder f, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      if (f.evaluate().isNotEmpty) {
        debugPrint('[shots] found ${f.describeMatch(Plurality.many)} after '
            '${DateTime.now().difference(start).inMilliseconds}ms');
        return true;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    return f.evaluate().isNotEmpty;
  }

  /// Like [pumpUntil], but fails the test with [what] if [f] never appears -
  /// so a spinner, an error or an empty state is never captured.
  Future<void> waitFor(
    WidgetTester tester,
    Finder f,
    String what, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!await pumpUntil(tester, f, timeout: timeout)) {
      fail('[shots] Timed out after ${timeout.inSeconds}s waiting for $what '
          '(${f.describeMatch(Plurality.many)}).');
    }
  }

  /// Lets animations and async work finish. pumpAndSettle throws a
  /// FlutterError (an Error, not an Exception) when something animates
  /// forever, so fall back to a fixed run of real frames.
  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Something animates indefinitely; real frames below cover it.
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
  }

  var surfaceConverted = false;

  /// Keyboard down, no snackbar, fonts loaded, frame settled - then capture.
  Future<void> shot(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (final messenger in tester
        .stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      messenger.clearSnackBars();
    }
    // The app's GoogleFonts are fetched at runtime; wait for the files so the
    // shot is not taken in the fallback font.
    await tester.runAsync(() async {
      try {
        await GoogleFonts.pendingFonts()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[shots] font load did not complete: $e');
      }
    });
    await settle(tester);
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
    debugPrint('[shots] captured $name');
  }

  final menuButton = find.byTooltip('Menu');

  /// Opens the home drawer and taps the entry [label].
  Future<void> openFromDrawer(WidgetTester tester, String label) async {
    await waitFor(tester, menuButton, 'the home screen menu button');
    await tester.tap(menuButton.first);
    final drawer = find.byType(Drawer);
    await waitFor(tester, drawer, 'the navigation drawer');
    await settle(tester);
    final item = find.descendant(of: drawer, matching: find.text(label));
    await tester.scrollUntilVisible(
      item,
      120,
      scrollable: find
          .descendant(of: drawer, matching: find.byType(Scrollable))
          .first,
    );
    await settle(tester);
    await tester.tap(item.first);
    await settle(tester);
  }

  /// Taps the AppBar's real back button and waits for home.
  Future<void> backToHome(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final back = find.byType(BackButton);
    await waitFor(tester, back, 'the back button');
    await tester.tap(back.last);
    await settle(tester);
    await waitFor(tester, menuButton, 'the home screen after going back');
  }

  testWidgets('store screenshots', (WidgetTester tester) async {
    app.main();
    await waitFor(tester, find.byType(MaterialApp), 'the app to start',
        timeout: const Duration(seconds: 120));

    // ── First launch: AuthGate shows LoginScreen on a clean install. Sign-in
    // is optional; take the app's own "Continue without signing in" button.
    final guest = find.text('Continue without signing in');
    await waitFor(
      tester,
      find.byWidgetPredicate(
          (w) => w is Text && w.data == 'Continue without signing in' ||
              w is Tooltip && w.message == 'Menu'),
      'the sign-in screen or the home screen',
      timeout: const Duration(seconds: 60),
    );
    if (guest.evaluate().isNotEmpty) {
      await tester.ensureVisible(guest);
      await tester.pump();
      await tester.tap(guest);
      await settle(tester);
    }
    await waitFor(tester, find.text('TRAINING MODULES'), 'the home dashboard',
        timeout: const Duration(seconds: 30));
    await settle(tester);

    // ── 01 Live weather: the Weather destination fetches a live METAR + TAF
    // for KJFK on open.
    final weatherTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Weather'),
    );
    if (weatherTab.evaluate().isNotEmpty) {
      await tester.tap(weatherTab.first);
    } else {
      await openFromDrawer(tester, 'Aviation Weather');
    }
    await waitFor(tester, find.text('LIVE WEATHER'), 'the weather screen');
    final rawMetar = find.text('RAW METAR');
    if (!await pumpUntil(tester, rawMetar)) {
      // One retry through the screen's own search button, in case the first
      // request failed transiently.
      final search = find.byIcon(Icons.search);
      if (search.evaluate().isNotEmpty) {
        await tester.tap(search.first);
      }
      await waitFor(tester, rawMetar, 'the live METAR for KJFK');
    }
    await shot(tester, '01_live_weather');
    await backToHome(tester);

    // ── 02 E6B: solve a wind triangle with realistic cross-country numbers.
    await openFromDrawer(tester, 'E6B Calculator');
    await waitFor(tester, find.text('E6B CALCULATOR'), 'the E6B screen');
    await waitFor(tester, find.text('WIND TRIANGLE'), 'the wind triangle');
    Future<void> type(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await waitFor(tester, field, 'the "$label" field');
      await tester.ensureVisible(field.first);
      await tester.enterText(field.first, value);
      await tester.pump();
    }

    await type('True Course', '285');
    await type('True Airspeed', '112');
    await type('Wind Direction (from)', '240');
    await type('Wind Speed', '18');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    // The solution card shows a heading once all four inputs are valid.
    await waitFor(
      tester,
      find.byWidgetPredicate((w) =>
          w is Semantics &&
          (w.properties.label?.startsWith('Heading (true): ') ?? false) &&
          !(w.properties.label?.endsWith('not available') ?? true)),
      'the computed E6B heading',
    );
    final windPanel = find.text('WIND TRIANGLE');
    await tester.ensureVisible(windPanel);
    await shot(tester, '02_e6b_wind_triangle');
    await backToHome(tester);

    // ── 03 Logbook: log two real-sounding flights through the app's own
    // "LOG FLIGHT" sheet. Stored in the on-device sqflite logbook only.
    await openFromDrawer(tester, 'Digital Logbook');
    await waitFor(tester, find.text('PILOT LOGBOOK'), 'the logbook screen');
    final emptyLog = find.text('No logbook entries yet');
    final entryTotal = find.text('Total');
    await waitFor(
      tester,
      find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data == 'No logbook entries yet' || w.data == 'Total')),
      'the logbook to load',
    );
    if (emptyLog.evaluate().isNotEmpty) {
      Future<void> logFlight({
        required String from,
        required String to,
        required String tail,
        required String total,
        required String remarks,
      }) async {
        final fab = find.text('LOG FLIGHT');
        await waitFor(tester, fab, 'the LOG FLIGHT button');
        await tester.tap(fab.first);
        await waitFor(tester, find.text('LOG NEW FLIGHT'), 'the log sheet');
        await settle(tester);
        Future<void> fill(String label, String value) async {
          final field = find.widgetWithText(TextFormField, label);
          await waitFor(tester, field, 'the "$label" field');
          await tester.ensureVisible(field.first);
          await tester.enterText(field.first, value);
          await tester.pump();
        }

        await fill('From (ICAO)', from);
        await fill('To (ICAO)', to);
        await fill('Aircraft Type', 'C172');
        await fill('Tail Number', tail);
        await fill('Total Time', total);
        await fill('PIC Time', total);
        await fill('Remarks', remarks);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final save = find.text('SAVE ENTRY');
        await tester.ensureVisible(save);
        await tester.pump();
        await tester.tap(save);
        await settle(tester);
        // SAVE ENTRY pops the sheet; make sure it is gone before going on.
        final start = DateTime.now();
        while (find.text('LOG NEW FLIGHT').evaluate().isNotEmpty) {
          if (DateTime.now().difference(start) > const Duration(seconds: 10)) {
            fail('[shots] The log sheet did not close after SAVE ENTRY.');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await settle(tester);
      }

      await logFlight(
        from: 'KPAO',
        to: 'KMRY',
        tail: 'N738SP',
        total: '1.4',
        remarks: 'Solo cross-country down the coast, flight following',
      );
      await waitFor(tester, find.text('KMRY'), 'the first logged flight');
      await logFlight(
        from: 'KMRY',
        to: 'KPAO',
        tail: 'N738SP',
        total: '1.3',
        remarks: 'Return leg via Salinas VOR, full-stop landing',
      );
      // Each entry card carries one "Total" stat; two cards = both saved.
      final start = DateTime.now();
      while (entryTotal.evaluate().length < 2) {
        if (DateTime.now().difference(start) > const Duration(seconds: 15)) {
          fail('[shots] The second logged flight never appeared.');
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
      }
    }
    await waitFor(tester, entryTotal, 'a logbook entry card');
    await shot(tester, '03_logbook');
    await backToHome(tester);

    // ── 04 Checklists: follow the Cessna 172 preflight and tick the first
    // few items. Ticks are stored on the device only.
    await openFromDrawer(tester, 'Smart Checklists');
    await waitFor(tester, find.text('CHECKLISTS'), 'the checklist screen');
    final unchecked = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.checked == false);
    final checked = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.checked == true);
    await waitFor(tester, find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.checked != null),
        'the checklist items');
    // Let the persisted state load before ticking, so a tick is not
    // overwritten by _loadState().
    await settle(tester);
    for (var i = 0;
        i < 8 &&
            checked.evaluate().length < 4 &&
            unchecked.evaluate().isNotEmpty;
        i++) {
      await tester.tap(unchecked.first);
      await settle(tester);
    }
    if (checked.evaluate().length < 4) {
      fail('[shots] Tapping checklist items did not tick them '
          '(${checked.evaluate().length} ticked).');
    }
    await shot(tester, '04_checklist');
    await backToHome(tester);

    // ── 05 FAA education hub: the certification pathway.
    await openFromDrawer(tester, 'FAA Education Hub');
    await waitFor(tester, find.text('CERTIFICATION PATHWAY'),
        'the FAA education hub');
    await waitFor(tester, find.text('Private Pilot (PPL)'),
        'the certification pathway');
    await shot(tester, '05_faa_education');
  });
}
