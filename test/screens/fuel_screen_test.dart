/// Fuel planning and reserve compliance.
///
/// Endurance and the reserve margin are the numbers a pilot uses to decide
/// whether a leg is legal and survivable, and the maths lives in the screen's
/// `build`, so these drive the real widgets and read the rendered answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/fuel_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openFuel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: FuelScreen()));
  await tester.pump();
}

Future<void> type(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('endurance and reserve', () {
    testWidgets('40 gallons at 10 gph is four hours, three and a half of them '
        'usable', (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      // The reserve field defaults to 30 minutes (VFR day).

      expect(find.text('04:00'), findsOneWidget); // total endurance
      expect(find.text('5.0 gal'), findsOneWidget); // 30 min at 10 gph
      expect(find.text('03:30'), findsOneWidget); // usable to reserve
      expect(find.text('RESERVE OK'), findsOneWidget);
    });

    testWidgets('with nothing entered the screen prompts instead of showing '
        'zeros', (tester) async {
      // Showing "00:00" endurance would look like a computed answer.
      await openFuel(tester);
      expect(find.text('ENTER FUEL & BURN'), findsOneWidget);
      expect(find.text('--:--'), findsNWidgets(2));
    });

    testWidgets('a reserve that swallows the whole tank reads BELOW RESERVE',
        (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Reserve', '240');

      expect(find.text('BELOW RESERVE'), findsOneWidget);
      expect(find.text('RESERVE OK'), findsNothing);
    });

    testWidgets('a ten-minute margin above reserve is flagged marginal, not ok',
        (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Reserve', '230');

      expect(find.text('MARGINAL RESERVE'), findsOneWidget);
      expect(find.text('00:10'), findsOneWidget);
    });

    testWidgets('the VFR night preset sets a 45 minute reserve',
        (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await tester.tap(find.text('VFR NIGHT'));
      await tester.pump();

      expect(find.text('7.5 gal'), findsOneWidget); // 45 min at 10 gph
      expect(find.text('03:15'), findsOneWidget); // 240 - 45
    });

    testWidgets('a zero burn rate is treated as no input, not infinite '
        'endurance', (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '0');

      expect(find.text('ENTER FUEL & BURN'), findsOneWidget);
      expect(find.textContaining('∞'), findsNothing);
    });
  });

  group('range and planned leg', () {
    testWidgets('still-air range uses the reserve-protected endurance, not the '
        'total', (tester) async {
      // 3h30 usable at 110 kt = 385 nm. Using the full 4h would advertise
      // 440 nm and invite a pilot to plan into the reserve.
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Ground speed (for range)', '110');

      expect(find.text('385 nm'), findsOneWidget);
    });

    testWidgets('fuel for a planned time is burn times hours', (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Planned time', '120');

      expect(find.text('20.0 gal'), findsOneWidget);
      expect(find.textContaining('EXCEEDS'), findsNothing);
    });

    testWidgets('planning past the usable endurance raises a reserve warning',
        (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Planned time', '220'); // usable is 210

      expect(find.textContaining('EXCEEDS USABLE'), findsOneWidget);
      expect(find.textContaining('EXCEEDS TOTAL'), findsNothing);
    });

    testWidgets('planning past the total endurance says the flight is not '
        'possible', (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Planned time', '250'); // total is 240

      expect(find.textContaining('EXCEEDS TOTAL ENDURANCE'), findsOneWidget);
    });

    testWidgets('a planned distance is converted through ground speed',
        (tester) async {
      // 220 nm at 110 kt = 2h00 and 20 gal at 10 gph.
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Ground speed (for range)', '110');
      await type(tester, 'Planned dist', '220');

      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('20.0 gal'), findsOneWidget);
    });

    testWidgets('a distance with no ground speed asks for one rather than '
        'guessing', (tester) async {
      await openFuel(tester);
      await type(tester, 'Total usable fuel', '40');
      await type(tester, 'Fuel burn rate', '10');
      await type(tester, 'Planned dist', '220');

      expect(
        find.text('Enter ground speed to compute distance-based fuel.'),
        findsOneWidget,
      );
    });
  });
}
