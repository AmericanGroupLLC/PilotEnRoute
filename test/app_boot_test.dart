/// Boot and navigation tests for the real `PilotEnRouteApp`.
///
/// The portfolio has already shipped an app that passed analysis and every
/// test while opening to a white screen, so these tests pump the *real* widget
/// tree — the real providers, the real route table, the real AuthGate — and
/// assert that something a pilot would recognise is on screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/main.dart';
import 'package:pilot_enroute/screens/home_screen.dart';
import 'package:pilot_enroute/screens/login_screen.dart';
import 'package:pilot_enroute/services/auth_service.dart';

/// Pumps the whole app and lets the first frames settle. `pumpAndSettle` is
/// deliberately avoided: the home screen runs a repeating "LIVE" pulse
/// animation that never quiesces.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const PilotEnRouteApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // AuthService is a process-wide singleton, so one test's session would
    // otherwise leak into the next.
    await AuthService.instance.signOut();
  });

  group('app boot', () {
    testWidgets('before the session restores, the root shows a splash rather '
        'than an empty frame', (tester) async {
      await pumpApp(tester);

      expect(AuthService.instance.isInitialized, isFalse,
          reason: 'precondition: nothing has initialised the session yet');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A blank white/black frame is exactly the shipped-bug class this guards.
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('a signed-out session lands on the login screen with its '
        'controls', (tester) async {
      await AuthService.instance.init();
      await pumpApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Continue without signing in'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('entering as a guest renders the real home dashboard, not a '
        'blank scaffold', (tester) async {
      await AuthService.instance.init();
      AuthService.instance.continueAsGuest();
      await pumpApp(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      // Real content, not just "a Scaffold exists".
      expect(find.text('PILOT EN ROUTE'), findsOneWidget);
      expect(find.text('TRAINING MODULES'), findsOneWidget);
      expect(find.byType(GridView), findsAtLeastNWidgets(1));
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the app supplies every provider its first screen reads',
        (tester) async {
      // A missing ChangeNotifierProvider throws ProviderNotFoundException at
      // build time and the user sees a red/blank screen; assert we never do.
      await AuthService.instance.init();
      AuthService.instance.continueAsGuest();
      await pumpApp(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('routing', () {
    /// Every destination reachable from the drawer / module grid, minus the
    /// handful that need real platform plumbing (see the skip list below).
    const routes = <String>[
      '/login',
      '/home',
      '/weather',
      '/news',
      '/quiz',
      '/airport',
      '/glossary',
      '/drone',
      '/garmin',
      '/education',
      '/flashcards',
      '/exam',
      '/flight-plan',
      '/flight-tracker',
      '/e6b',
      '/weight-balance',
      '/fuel',
      '/notams',
      '/ai',
      '/account',
      '/debrief',
      '/alerts',
      '/integrations',
      '/charts',
      // '/wind' is excluded: WindScreen embeds a WebView and webview_flutter
      // has no platform implementation under `flutter test`. Covered by the
      // route-registration test below instead.
      '/radio',
      '/regulations',
      '/navdb',
      '/endorsements',
      '/career',
      '/notifications',
      '/icara',
      '/checklist',
      '/emergency',
      '/profile',
    ];

    for (final route in routes) {
      testWidgets('$route opens a real screen', (tester) async {
        await AuthService.instance.init();
        AuthService.instance.continueAsGuest();
        await pumpApp(tester);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pushNamed(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // An unregistered route throws; a screen that fails to build throws.
        expect(tester.takeException(), isNull,
            reason: '$route must build without an exception');
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        // A screen with no text at all is the white-screen signature.
        expect(find.byType(Text), findsAtLeastNWidgets(1),
            reason: '$route rendered no text — likely a blank screen');
      });
    }

    testWidgets('the bottom navigation bar reaches its destinations',
        (tester) async {
      await AuthService.instance.init();
      AuthService.instance.continueAsGuest();
      await pumpApp(tester);

      // Scope the finder to the nav bar: Icons.quiz and Icons.cloud also
      // appear on module cards in the grid above.
      final navBar = find.byType(BottomNavigationBar);
      await tester.tap(
        find.descendant(of: navBar, matching: find.byIcon(Icons.quiz)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      // A pushed route covers the dashboard; if the tap were wired to nothing
      // the home screen would still be the top route.
      expect(find.byType(HomeScreen), findsNothing,
          reason: 'tapping Quiz must push a new route over the dashboard');
    });

    test('every route literal used in the UI is registered in main.dart', () {
      // The drawer and the module grid navigate by string. A renamed or
      // deleted route shows up here instead of as a runtime crash for a user
      // who taps that one entry.
      final mainSrc = File('lib/main.dart').readAsStringSync();
      final registered = RegExp(r"'(/[a-z0-9-]*)':")
          .allMatches(mainSrc)
          .map((m) => m.group(1)!)
          .toSet();
      expect(registered, contains('/'),
          reason: 'the root route must exist or the app opens to nothing');

      // Navigation by name (`pushNamed('/x')`) and by ModuleData/drawer entry
      // (`route: '/x'`) are the two ways this app names a destination.
      final navPattern = RegExp(
        r"(?:push(?:Replacement|AndRemoveUntil)?Named|popAndPushNamed)"
        r"\s*\([^)]*?'(/[a-z0-9-]+)'"
        r"|route:\s*'(/[a-z0-9-]+)'",
      );

      final referenced = <String>{};
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (file.path.endsWith('main.dart')) continue;
        for (final m in navPattern.allMatches(file.readAsStringSync())) {
          referenced.add((m.group(1) ?? m.group(2))!);
        }
      }

      expect(referenced, isNotEmpty,
          reason: 'the scan found no routes at all — the pattern is stale');
      expect(referenced.difference(registered), isEmpty,
          reason: 'these route literals are navigated to but not registered');
    });
  });

  group('session transitions', () {
    testWidgets('signing out returns the user to the login screen',
        (tester) async {
      await AuthService.instance.init();
      AuthService.instance.continueAsGuest();
      await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // signOut() awaits real platform channels, which the fake-async clock
      // inside testWidgets will never resolve — runAsync gives it a real loop.
      await tester.runAsync(() => AuthService.instance.signOut());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a persisted offline session opens straight into the app',
        (tester) async {
      // Mirrors a returning user: the session keys are already on disk, so the
      // login screen must not appear at all.
      SharedPreferences.setMockInitialValues({
        'agl_is_local_session': true,
        'agl_user_id': 'local-demo-user',
        'agl_local_email': 'pilot@example.com',
        'agl_local_name': 'Test Pilot',
      });
      await AuthService.instance.init();
      await pumpApp(tester);

      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
