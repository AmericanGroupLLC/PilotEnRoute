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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/screens/checklist_screen.dart';
import 'package:pilot_enroute/screens/fuel_screen.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/minimums/minimums_check.dart';
import 'package:pilot_enroute/ui/status_tag.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

      await tester.pumpWidget(const MaterialApp(home: ChecklistScreen()));
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

      await tester.pumpWidget(const MaterialApp(home: ChecklistScreen()));
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

  group('Go Card semantics', () {
    testWidgets('a status tag is read as its word, not as a colour',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            StatusTag(lookForCheck(CheckState.outside)),
            StatusTag(lookForCheck(CheckState.near)),
            StatusTag(lookForRule(const RuleStatus(
              id: RuleId.medical,
              title: 'Medical',
              cite: '14 CFR 61.23',
              shortLabel: 'medical',
              required: true,
              state: RuleState.valid,
              summary: 'x',
            ))),
          ]),
        ),
      ));
      expect(find.bySemanticsLabel('OUTSIDE'), findsOneWidget);
      expect(find.bySemanticsLabel('NEAR'), findsOneWidget);
      expect(find.bySemanticsLabel('VALID'), findsOneWidget);
      handle.dispose();
    });
  });
}
