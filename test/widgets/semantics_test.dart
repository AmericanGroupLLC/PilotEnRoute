/// Accessibility: the screen-reader labels a blind pilot actually hears.
///
/// Icon-only controls, colour-coded status chips and big numeric read-outs
/// carry meaning that is invisible to TalkBack/VoiceOver unless it is spelled
/// out in the semantics tree. These tests pin the labels on the primary
/// screens so a refactor cannot silently drop them again.
library;

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/screens/checklist_screen.dart';
import 'package:pilot_enroute/screens/emergency_screen.dart';
import 'package:pilot_enroute/screens/fuel_screen.dart';
import 'package:pilot_enroute/screens/home_screen.dart';
import 'package:pilot_enroute/services/aviation_api_service.dart';
import 'package:pilot_enroute/services/news_service.dart';
import 'package:pilot_enroute/services/weather_service.dart';

Widget wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AviationApiService>(
          create: (_) => AviationApiService()),
      ChangeNotifierProvider<NewsService>(create: (_) => NewsService()),
      ChangeNotifierProvider<WeatherService>(create: (_) => WeatherService()),
    ],
    child: MaterialApp(
      home: child,
      routes: {
        '/store': (_) => const Scaffold(body: Text('Store')),
        '/news': (_) => const Scaffold(body: Text('News')),
        '/weather': (_) => const Scaffold(body: Text('Weather')),
      },
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HomeScreen semantics', () {
    testWidgets('module cards announce a name and their badge, with the '
        'layout line break removed', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      // 'Basic Flight\nSim' must not be read with a pause mid-name.
      expect(find.bySemanticsLabel('Basic Flight Sim'), findsOneWidget);
      expect(find.bySemanticsLabel('Live Weather, LIVE'), findsOneWidget);
      expect(find.bySemanticsLabel('Smart Checklists'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the live-data cards read as buttons; no store promo',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.bySemanticsLabel('METAR, Live airport weather'),
        findsOneWidget,
      );
      final metar = tester.getSemantics(
        find.bySemanticsLabel('METAR, Live airport weather'),
      );
      expect(metar.flagsCollection.isButton, isTrue);

      // The Pilot Gear Store (invented ratings, dead affiliate links) is gone.
      expect(
        find.bySemanticsLabel(RegExp('Pilot Gear Store')),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('the hero stat badges are read as one phrase, not two '
        'orphan fragments', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.bySemanticsLabel('500+ Airports'), findsOneWidget);
      expect(find.bySemanticsLabel('13 Subjects'), findsOneWidget);

      handle.dispose();
    });
  });

  group('FuelScreen semantics', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: FuelScreen()));
      await tester.pump();
    }

    Future<void> type(WidgetTester t, String label, String value) async {
      await t.enterText(find.widgetWithText(TextField, label), value);
      await t.pump();
    }

    testWidgets('reserve compliance is announced in words, not only in colour',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');

      expect(
        find.bySemanticsLabel('Reserve status: RESERVE OK'),
        findsOneWidget,
      );

      await type(tester, 'Reserve', '240');
      expect(
        find.bySemanticsLabel('Reserve status: BELOW RESERVE'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('an HH:MM endurance is spoken as a duration', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');

      // On screen this reads '04:00', which a screen reader would otherwise
      // announce as a clock time.
      expect(
        find.bySemanticsLabel('Total endurance: 4 hours 0 minutes'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Usable to reserve: 3 hours 30 minutes'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('placeholders are announced as unavailable rather than read '
        'as dashes', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);

      expect(
        find.bySemanticsLabel('Total endurance: not available'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('the reserve presets and interval steppers are named buttons',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);

      expect(
        find.bySemanticsLabel('VFR NIGHT reserve, 45 minutes'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Increase switch interval'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Decrease switch interval'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('ChecklistScreen semantics', () {
    testWidgets('a checklist line exposes its action, target value and '
        'checked state', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const ChecklistScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      final item = find.bySemanticsLabel(
        'Fuel Quantity, CHECK VISUALLY, critical item',
      );
      expect(item, findsOneWidget);

      var node = tester.getSemantics(item);
      expect(node.flagsCollection.isChecked, CheckedState.isFalse);

      await tester.tap(find.text('Fuel Quantity'));
      await tester.pumpAndSettle();

      node = tester.getSemantics(item);
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);

      handle.dispose();
    });

    testWidgets('progress through the phase is announced as a sentence',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const ChecklistScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.bySemanticsLabel(
          RegExp(r'^0 of \d+ items complete in the Preflight checklist$'),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('EmergencyScreen semantics', () {
    testWidgets('a scenario card reads its difficulty and time limit',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const EmergencyScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      final card = find.bySemanticsLabel(
        RegExp(r'difficulty, \d+ second time limit$'),
      );
      expect(card, findsAtLeastNWidgets(1));
      expect(
        tester.getSemantics(card.first).flagsCollection.isButton,
        isTrue,
      );

      handle.dispose();
    });
  });
}
