/// Boot and navigation tests for the real `PilotEnRouteApp`.
///
/// The portfolio has already shipped an app that passed analysis and every
/// test while opening to a white screen, so these pump the *real* widget tree
/// — the real providers, the real RootGate, the real route table — and
/// assert that something a pilot would recognise is on screen. There is no
/// login wall: a fresh install opens onboarding, then Today.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/main.dart';
import 'package:pilot_enroute/screens/app_shell.dart';
import 'package:pilot_enroute/screens/kit_screen.dart';
import 'package:pilot_enroute/screens/logbook_screen.dart';
import 'package:pilot_enroute/screens/onboarding_screen.dart';
import 'package:pilot_enroute/screens/today_screen.dart';
import 'package:pilot_enroute/screens/weather_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/notification_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:pilot_enroute/widgets/ad_banner_widget.dart';

import 'support/awc_fixtures.dart';

Future<void> pumpApp(WidgetTester tester, SettingsStore settings) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PilotEnRouteApp(
    settings: settings,
    logbook: LogbookService(store: MemoryLogbookStore()),
    clock: () => DateTime.utc(2026, 10, 14, 13, 10),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

/// Lets the reminder debounce timer fire so no timer is left pending.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.permissionRequester = () async => false;
    NotificationService.permissionChecker = () async => false;
    NotificationService.reminderCanceller = (_) async {};
  });

  group('app boot', () {
    testWidgets('a fresh install opens onboarding, not a login screen',
        (tester) async {
      await http.runWithClient(() async {
        await pumpApp(tester, await SettingsStore.load());
      }, awcClient);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Am I legal, and inside my minimums?'), findsOneWidget);
      expect(find.text('SIGN IN'), findsNothing);
      expect(find.textContaining('Continue without signing in'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finishing onboarding lands on Today for that airport, and a '
        'relaunch skips it', (tester) async {
      await http.runWithClient(() async {
        await pumpApp(tester, await SettingsStore.load());
        await tester.enterText(
            find.byKey(const Key('onboarding-airport')), 'kpao');
        await tester.tap(find.byKey(const Key('class-ASEL')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding-next-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onboarding-skip-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onboarding-skip-3')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
      }, awcClient);

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(TodayScreen), findsOneWidget);
      final dep = tester.widget<TextField>(find.byKey(const Key('go-departure')));
      expect(dep.controller!.text, 'KPAO');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SettingsStore.kOnboarding), isTrue);
      expect(prefs.getString(SettingsStore.kHomeAirport), 'KPAO');

      // Relaunch with what was saved.
      final reloaded = await SettingsStore.load();
      expect(reloaded.onboardingDone, isTrue);
      expect(reloaded.profile.homeCategoryClass, 'ASEL');
      await http.runWithClient(() async {
        await pumpApp(tester, reloaded);
        await settle(tester);
      }, awcClient);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    // Regression for the iOS 27 QA freeze (2026-10-14): onboarding done with
    // KPAO, ASEL, a flight review date and day minimums. Today must finish
    // its first check, and opening the app must not touch the notification
    // system beyond one permission check (and nothing on a relaunch).
    testWidgets('launch with a flight review and day minimums: Today '
        'finishes the check and no reminder call blocks the way',
        (tester) async {
      final cancelled = <int>[];
      var checked = 0;
      NotificationService.reminderCanceller = (id) async => cancelled.add(id);
      NotificationService.permissionChecker = () async {
        checked++;
        return false;
      };
      SharedPreferences.setMockInitialValues({
        SettingsStore.kOnboarding: true,
        SettingsStore.kHomeAirport: 'KPAO',
        SettingsStore.kProfile: jsonEncode(PilotProfile(
          flightReviewDate: DateTime(2026, 10, 14),
          homeCategoryClass: 'ASEL',
        ).toJson()),
        SettingsStore.kMinimums: jsonEncode(const PersonalMinimums(
            day: MinimumsSet(
                ceilingFt: 2000,
                visibilitySm: 5,
                maxWindKt: 20,
                maxGustKt: 25,
                maxCrosswindKt: 10)).toJson()),
      });
      await http.runWithClient(() async {
        await pumpApp(tester, await SettingsStore.load());
        await settle(tester);
      }, awcClient);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Checking…'), findsNothing);
      expect(find.text('Not legal: medical not on record'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Your limit ≥ 2000 ft'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(TodayScreen),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('Your limit ≥ 2000 ft'), findsOneWidget);
      expect(cancelled, isEmpty);
      expect(checked, 1);

      // Relaunch with the same data: nothing reaches the OS at all.
      await http.runWithClient(() async {
        await pumpApp(tester, await SettingsStore.load());
        await settle(tester);
      }, awcClient);
      expect(find.text('Checking…'), findsNothing);
      expect(cancelled, isEmpty);
      expect(checked, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('screen 1 cannot be skipped without an airport and a class',
        (tester) async {
      await pumpApp(tester, await SettingsStore.load());
      final next = tester.widget<FilledButton>(
          find.byKey(const Key('onboarding-next-1')));
      expect(next.onPressed, isNull);
    });
  });

  group('shell', () {
    Future<void> openShell(WidgetTester tester) async {
      await http.runWithClient(() async {
        await pumpApp(
            tester, SettingsStore(onboardingDone: true, homeAirport: 'KPAO'));
        await settle(tester);
      }, awcClient);
    }

    testWidgets('four tabs: Today, Logbook, Weather, Kit', (tester) async {
      await openShell(tester);
      for (final label in AppShell.tabLabels) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      final shell = tester.state<AppShellState>(find.byType(AppShell));
      for (final (i, type) in [
        (1, LogbookScreen),
        (2, WeatherScreen),
        (3, KitScreen),
        (0, TodayScreen),
      ]) {
        await http.runWithClient(() async {
          await tester.tap(find.text(AppShell.tabLabels[i]).last);
          await tester.pump(const Duration(milliseconds: 400));
        }, awcClient);
        expect(shell.index, i);
        expect(find.byType(type), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await settle(tester);
    });

    testWidgets('no drawer and no module grid', (tester) async {
      await openShell(tester);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('TRAINING MODULES'), findsNothing);
    });

    testWidgets('Today carries no ad, not even off-screen', (tester) async {
      await openShell(tester);
      expect(
          find.descendant(
              of: find.byType(TodayScreen),
              matching: find.byType(AdBannerWidget)),
          findsNothing);
    });
  });

  group('routing', () {
    for (final route in RootGate.routes) {
      testWidgets('$route opens a real screen', (tester) async {
        await http.runWithClient(() async {
          await pumpApp(
              tester, SettingsStore(onboardingDone: true, homeAirport: 'KPAO'));
          final navigator =
              tester.state<NavigatorState>(find.byType(Navigator).first);
          navigator.pushNamed(route);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await settle(tester);
        }, awcClient);
        expect(tester.takeException(), isNull,
            reason: '$route must build without an exception');
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        expect(find.byType(Text), findsAtLeastNWidgets(1),
            reason: '$route rendered no text — likely a blank screen');
      });
    }

    test('every route literal used in the UI is registered in main.dart', () {
      final mainSrc = File('lib/main.dart').readAsStringSync();
      final registered = RegExp(r"case '(/[a-z0-9-]*)':")
          .allMatches(mainSrc)
          .map((m) => m.group(1)!)
          .toSet();
      expect(registered, containsAll(RootGate.routes));
      final referenced = <String>{};
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (file.path.endsWith('main.dart')) continue;
        final src = file.readAsStringSync();
        referenced.addAll(RegExp(r"pushNamed\(\s*'(/[a-z0-9-]+)'")
            .allMatches(src)
            .map((m) => m.group(1)!));
        // The Kit list names its destinations as ('/route', ...) records.
        referenced.addAll(RegExp(r"\('(/[a-z0-9-]+)',")
            .allMatches(src)
            .map((m) => m.group(1)!));
      }
      expect(referenced, isNotEmpty);
      expect(referenced.difference(registered), isEmpty,
          reason: 'navigated to but not registered');
    });
  });
}
