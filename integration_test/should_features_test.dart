// On-device check of spec S1-S3 and the Kit "About" sheets, on the real app.
//
// VERIFICATION ONLY, never store art: the driver writes to
// build/verify_screenshots/. The profile is set to a student pilot through
// SharedPreferences before launch, and the logbook is filled through the
// real "Paste CSV" UI from a clipboard text this test writes. Those flights
// are test data, labelled "verification" in their remarks.
//
// Run:
//   flutter drive --driver=test_driver/verify_driver.dart \
//     --target=integration_test/should_features_test.dart \
//     --dart-define=SCREENSHOT=true -d <simulator>
// Add --dart-define=VERIFY_OFFLINE=true where the device has no internet
// (the Android emulator on this Mac): that skips only the live-weather step.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/logbook/logbook_csv.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/main.dart' as app;
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> pumpUntil(WidgetTester tester, Finder f,
      {Duration timeout = const Duration(seconds: 30)}) async {
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
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (!await pumpUntil(tester, f, timeout: timeout)) {
      fail('Timed out waiting for $what');
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
  }

  var surfaceConverted = false;

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
    debugPrint('[verify] captured $name');
  }

  Future<void> tap(WidgetTester tester, Finder f, String what) async {
    await waitFor(tester, f, what);
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle(tester);
  }

  testWidgets('S1-S3 and Kit About on device', (tester) async {
    final today = DateTime.now();
    LogbookEntry lesson(int daysAgo, {double dual = 0, double solo = 0,
            double xc = 0, double night = 0, int nightLdg = 0}) =>
        LogbookEntry(
          date: DateTime(today.year, today.month, today.day - daysAgo),
          aircraftType: 'C172',
          tailNumber: 'N00000',
          categoryClass: 'ASEL',
          from: 'KPAO',
          to: 'KPAO',
          totalTime: dual + solo,
          dualReceived: dual,
          soloTime: solo,
          crossCountry: xc,
          night: night,
          dayTakeoffs: 3,
          dayLandings: 3,
          nightTakeoffs: nightLdg,
          nightLandings: nightLdg,
          remarks: 'verification',
        );
    final csv = logbookToCsv([
      lesson(40, dual: 1.5),
      lesson(33, dual: 1.4),
      lesson(26, dual: 1.6, xc: 1.6),
      lesson(19, dual: 1.5, night: 1.5, nightLdg: 5),
      lesson(12, solo: 1.0),
      lesson(5, solo: 1.2, xc: 1.2),
    ]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool(SettingsStore.kOnboarding, true);
    await prefs.setString(SettingsStore.kHomeAirport, 'KPAO');
    await prefs.setString(
        SettingsStore.kProfile,
        jsonEncode(const PilotProfile(
                studentPilot: true, homeCategoryClass: 'ASEL')
            .toJson()));

    app.main();
    await waitFor(tester, find.text('Check this flight'), 'Today',
        timeout: const Duration(seconds: 120));

    // S2: Night on; the window appears once the live KPAO check returns
    // (the airport position comes from aviationweather.gov). Skipped with
    // --dart-define=VERIFY_OFFLINE=true on a device with no internet.
    if (!const bool.fromEnvironment('VERIFY_OFFLINE')) {
      await tap(tester, find.text('Night'), 'Night chip');
      await waitFor(tester, find.byKey(const Key('go-night-window')),
          'the night window line', timeout: const Duration(seconds: 60));
      await tester.ensureVisible(find.byKey(const Key('go-night-window')));
      expect(
          find.textContaining(
              'Night for passenger currency (61.57(b)) at KPAO'),
          findsOneWidget);
      await shot(tester, 'v1_today_night_window');
    }

    // S3: Paste CSV through the real menu and dialog.
    await Clipboard.setData(ClipboardData(text: csv));
    await tap(tester, find.text('Logbook').last, 'Logbook tab');
    await tap(tester, find.byTooltip('Export'), 'Export menu');
    await tap(tester, find.text('Paste CSV'), 'Paste CSV');
    await waitFor(tester, find.text('6 flights to add.'), 'paste dialog');
    await shot(tester, 'v2_paste_csv_dialog');
    await tap(tester, find.text('Add 6'), 'Add 6');
    await waitFor(tester, find.text('Added 6 flights from CSV'), 'snackbar');

    // S1: the student card on Totals and the progress screen.
    await tap(tester, find.text('Totals'), 'Totals tab');
    await waitFor(tester, find.byKey(const Key('student-progress-card')),
        'student progress card');
    await shot(tester, 'v3_totals_student_card');
    await tap(tester, find.byKey(const Key('student-progress-card')), 'card');
    await waitFor(tester, find.text('61.109(a) · 8.2 of 40.0 h'),
        'total flight time 8.2 h');
    expect(find.text('61.109(a) · 6.0 of 20.0 h'), findsOneWidget);
    await shot(tester, 'v4_student_progress');
    await tap(tester, find.byType(BackButton), 'back');

    // Kit About sheet.
    await tap(tester, find.text('Kit').last, 'Kit tab');
    await tap(tester, find.byTooltip('About E6B'), 'About E6B');
    await waitFor(tester, find.textContaining('wind triangle'), 'E6B text');
    await shot(tester, 'v5_kit_about_e6b');
  });
}
