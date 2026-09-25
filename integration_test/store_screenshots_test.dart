// BESPOKE store screenshots for PilotEnRoute - do not regenerate.
//
// The generic .sweep/capture_screenshots.py test produced nothing but
// single-colour frames here, because main() awaits AdService().initialize()
// before runApp() (lib/main.dart) and that gathers UMP consent, so on a clean
// install nothing is painted for several seconds - and pumpAndSettle returns
// immediately while nothing is mounted, so every shot was of the blank window
// before the app existed. This waits for real widgets instead of for an idle
// frame, then signs in as a guest, which is the only door that opens without
// a network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pilot_enroute/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps real frames until [f] matches, or [timeout] elapses.
  ///
  /// pumpAndSettle is wrong for this twice over: it throws a FlutterError (an
  /// Error, so `on Exception` misses it) when anything animates forever, and
  /// it returns instantly when nothing is animating - which is exactly the
  /// state while main() is still awaiting and no widget has been built.
  Future<bool> pumpUntil(
    WidgetTester tester,
    Finder f, {
    Duration timeout = const Duration(seconds: 150),
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
    debugPrint('[shots] TIMED OUT waiting for ${f.describeMatch(Plurality.many)}');
    return false;
  }

  Future<void> quiet(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)));
    }
  }

  testWidgets('store screenshots', (WidgetTester tester) async {
    app.main();
    await pumpUntil(tester, find.byType(MaterialApp));

    // AuthGate holds a spinner until AuthService reports initialised, then
    // shows the sign-in screen because a clean install has no session.
    if (await pumpUntil(tester, find.text('Continue without signing in'),
        timeout: const Duration(seconds: 60))) {
      await quiet(tester);
      await binding.takeScreenshot('01_signin');
      await tester.tap(find.text('Continue without signing in'),
          warnIfMissed: false);
    }

    await pumpUntil(tester, find.byType(BottomNavigationBar),
        timeout: const Duration(seconds: 60));
    await quiet(tester);
    await binding.takeScreenshot('02_home');

    // Store is the destination that renders real content from bundled data.
    // Weather needs a METAR fetch this machine cannot make, and Quiz loads
    // its question bank over the network, so both are empty states offline.
    var n = 2;
    for (final tab in <String>['Store']) {
      final f = find.text(tab);
      if (f.evaluate().isEmpty) continue;
      await tester.tap(f.last, warnIfMissed: false);
      await quiet(tester);
      n += 1;
      await binding.takeScreenshot('0${n}_${tab.toLowerCase()}');
      // Each tab pushes a route rather than swapping the body, so come back.
      final back = find.byTooltip('Back');
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first, warnIfMissed: false);
        await quiet(tester);
      }
    }
  });
}
