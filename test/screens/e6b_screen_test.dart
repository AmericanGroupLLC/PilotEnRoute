/// E6B flight-computer tests.
///
/// The wind triangle, crosswind, TAS/density-altitude, time-speed-distance,
/// fuel and unit-conversion maths all live inside the screen's `build`
/// methods, so the only honest way to pin them is to drive the real widgets
/// and read the rendered answer. That also means these tests fail both when
/// the arithmetic is wrong and when a field is wired to the wrong controller —
/// the two ways a pilot ends up with a confidently wrong number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/e6b_screen.dart';

/// Opens the E6B on the tab whose label is [tab]. The surface is widened so
/// the scrollable TabBar shows all six tabs at once.
Future<void> openTab(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: E6BScreen()));
  await tester.pump();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pump();
}

void main() {
  group('wind triangle', () {
    testWidgets('a 90-degree crosswind gives an 11.5 degree correction and a '
        'ground speed below TAS', (tester) async {
      // TC 090, TAS 100, wind from 180 at 20:
      //   WCA = asin(20·sin90 / 100) = 11.537 deg right
      //   HDG = 090 + 11.5 -> 102
      //   GS  = 100·cos(11.537) - 20·cos(90) = 97.98 -> 98
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '90');
      await type(tester, 'True Airspeed', '100');
      await type(tester, 'Wind Direction (from)', '180');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('102°'), findsOneWidget);
      expect(find.text('98 kt'), findsOneWidget);
      expect(find.text('11.5° R'), findsOneWidget);
    });

    testWidgets('a direct headwind leaves the heading on the course',
        (tester) async {
      // Wind from dead ahead: no correction, GS = TAS - wind.
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '360');
      await type(tester, 'True Airspeed', '100');
      await type(tester, 'Wind Direction (from)', '360');
      await type(tester, 'Wind Speed', '20');

      // North is rendered as 0°, not the conventional 360° — pinned here so a
      // change to the display convention is a deliberate one.
      expect(find.text('0°'), findsOneWidget);
      expect(find.text('80 kt'), findsOneWidget);
      expect(find.text('0.0° R'), findsOneWidget);
    });

    testWidgets('a direct tailwind adds to ground speed', (tester) async {
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '360');
      await type(tester, 'True Airspeed', '100');
      await type(tester, 'Wind Direction (from)', '180');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('120 kt'), findsOneWidget);
    });

    testWidgets('a wind from the left corrects left, not right',
        (tester) async {
      // Sign errors here point the aeroplane the wrong side of course.
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '90');
      await type(tester, 'True Airspeed', '100');
      await type(tester, 'Wind Direction (from)', '360');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('11.5° L'), findsOneWidget);
      expect(find.text('78°'), findsOneWidget);
    });

    testWidgets('incomplete input shows a dash rather than a wrong answer',
        (tester) async {
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '90');
      // No TAS, no wind: the solution must stay blank.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('a zero true airspeed does not produce infinity',
        (tester) async {
      await openTab(tester, 'WIND');
      await type(tester, 'True Course', '90');
      await type(tester, 'True Airspeed', '0');
      await type(tester, 'Wind Direction (from)', '180');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('∞'), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
    });
  });

  group('crosswind component', () {
    testWidgets('wind 30 degrees off the nose is 10 across and 17 down the '
        'runway', (tester) async {
      // 20 kt at 30 deg: cross = 20·sin30 = 10, head = 20·cos30 = 17.3.
      await openTab(tester, 'X-WIND');
      await type(tester, 'Runway Heading', '360');
      await type(tester, 'Wind Direction (from)', '30');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('10 kt'), findsOneWidget);
      expect(find.text('10 kt from right'), findsOneWidget);
      expect(find.text('17 kt'), findsOneWidget);
      expect(find.text('17 kt headwind'), findsOneWidget);
    });

    testWidgets('wind from the left of the runway reads "from left"',
        (tester) async {
      await openTab(tester, 'X-WIND');
      await type(tester, 'Runway Heading', '360');
      await type(tester, 'Wind Direction (from)', '330');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('10 kt from left'), findsOneWidget);
    });

    testWidgets('a wind from behind is labelled a tailwind, not a headwind',
        (tester) async {
      // Reading a 20 kt tailwind as a headwind is a runway-overrun error.
      await openTab(tester, 'X-WIND');
      await type(tester, 'Runway Heading', '360');
      await type(tester, 'Wind Direction (from)', '180');
      await type(tester, 'Wind Speed', '20');

      expect(find.text('Tailwind'), findsOneWidget);
      expect(find.text('20 kt tailwind'), findsOneWidget);
      expect(find.text('Headwind'), findsNothing);
    });

    testWidgets('a wind straight down the runway has no crosswind',
        (tester) async {
      await openTab(tester, 'X-WIND');
      await type(tester, 'Runway Heading', '90');
      await type(tester, 'Wind Direction (from)', '90');
      await type(tester, 'Wind Speed', '15');

      expect(find.text('0 kt'), findsOneWidget);
      expect(find.text('15 kt headwind'), findsOneWidget);
    });
  });

  group('true airspeed and density altitude', () {
    testWidgets('a hot day at 5000 ft gives 8000 ft density altitude',
        (tester) async {
      // PA = 5000 (altimeter 29.92), ISA = 15 - 2·5 = 5 C,
      // DA = 5000 + 120·(30 - 5) = 8000, TAS = 100 / sqrt(sigma) = 113.
      await openTab(tester, 'TAS / DA');
      await type(tester, 'Field Elevation', '5000');
      await type(tester, 'Altimeter Setting', '29.92');
      await type(tester, 'Outside Air Temp (OAT)', '30');
      await type(tester, 'Calibrated Airspeed (CAS/IAS)', '100');

      expect(find.text('5,000 ft'), findsOneWidget);
      expect(find.text('8,000 ft'), findsOneWidget);
      expect(find.text('5.0 °C'), findsOneWidget);
      expect(find.text('113 kt'), findsOneWidget);
    });

    testWidgets('a low altimeter setting raises pressure altitude',
        (tester) async {
      // 29.42 inHg is 0.5 inHg low, worth +500 ft of pressure altitude.
      await openTab(tester, 'TAS / DA');
      await type(tester, 'Field Elevation', '1000');
      await type(tester, 'Altimeter Setting', '29.42');

      expect(find.text('1,500 ft'), findsOneWidget);
    });

    testWidgets('a high altimeter setting lowers pressure altitude',
        (tester) async {
      await openTab(tester, 'TAS / DA');
      await type(tester, 'Field Elevation', '1000');
      await type(tester, 'Altimeter Setting', '30.42');

      expect(find.text('500 ft'), findsOneWidget);
    });

    testWidgets('at sea level on a standard day TAS equals CAS',
        (tester) async {
      await openTab(tester, 'TAS / DA');
      await type(tester, 'Field Elevation', '0');
      await type(tester, 'Altimeter Setting', '29.92');
      await type(tester, 'Outside Air Temp (OAT)', '15');
      await type(tester, 'Calibrated Airspeed (CAS/IAS)', '120');

      expect(find.text('0 ft'), findsAtLeastNWidgets(1));
      expect(find.text('120 kt'), findsOneWidget);
    });
  });

  group('time, speed and distance', () {
    testWidgets('60 NM at 120 kt takes half an hour', (tester) async {
      await openTab(tester, 'TIME-SPD-DIST');
      await type(tester, 'Ground Speed', '120');
      await type(tester, 'Distance', '60');

      expect(find.text('0h 30m'), findsOneWidget);
      expect(find.text('30.0 min'), findsOneWidget);
    });

    testWidgets('solving for speed divides distance by time', (tester) async {
      await openTab(tester, 'TIME-SPD-DIST');
      await tester.tap(find.text('SPEED'));
      await tester.pumpAndSettle();
      await type(tester, 'Distance', '90');
      await type(tester, 'Time', '45');

      expect(find.text('120.0 kt'), findsOneWidget);
    });

    testWidgets('solving for distance multiplies speed by time',
        (tester) async {
      await openTab(tester, 'TIME-SPD-DIST');
      await tester.tap(find.text('DIST'));
      await tester.pumpAndSettle();
      await type(tester, 'Ground Speed', '110');
      await type(tester, 'Time', '90');

      expect(find.text('165.0 NM'), findsOneWidget);
    });

    testWidgets('a zero ground speed shows a dash, not an infinite time',
        (tester) async {
      await openTab(tester, 'TIME-SPD-DIST');
      await type(tester, 'Ground Speed', '0');
      await type(tester, 'Distance', '60');

      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('∞'), findsNothing);
    });
  });

  group('fuel planning', () {
    testWidgets('90 minutes at 9 gph needs 13.5 gallons', (tester) async {
      await openTab(tester, 'FUEL');
      await type(tester, 'Fuel Burn', '9');
      await type(tester, 'Flight Time', '90');

      expect(find.text('13.5 gal'), findsOneWidget);
    });

    testWidgets('40 gallons at 10 gph is four hours of endurance',
        (tester) async {
      await openTab(tester, 'FUEL');
      await tester.tap(find.text('ENDURANCE'));
      await tester.pumpAndSettle();
      await type(tester, 'Fuel Burn', '10');
      await type(tester, 'Fuel Quantity', '40');

      expect(find.text('4h 00m'), findsOneWidget);
      expect(find.text('240.0 min'), findsOneWidget);
    });

    testWidgets('burn rate is gallons over hours, not over minutes',
        (tester) async {
      // 12 gal in 90 min is 8 gph. Forgetting the /60 would read 0.13.
      await openTab(tester, 'FUEL');
      await tester.tap(find.text('BURN RATE'));
      await tester.pumpAndSettle();
      await type(tester, 'Flight Time', '90');
      await type(tester, 'Fuel Quantity', '12');

      expect(find.text('8.0 gph'), findsOneWidget);
    });

    testWidgets('a zero burn rate shows a dash rather than infinite endurance',
        (tester) async {
      await openTab(tester, 'FUEL');
      await tester.tap(find.text('ENDURANCE'));
      await tester.pumpAndSettle();
      await type(tester, 'Fuel Burn', '0');
      await type(tester, 'Fuel Quantity', '40');

      expect(find.text('—'), findsWidgets);
    });
  });

  group('unit conversion', () {
    testWidgets('100 NM is 115.08 statute miles', (tester) async {
      await openTab(tester, 'CONVERT');
      await type(tester, 'Value', '100');

      expect(find.text('115.08 SM'), findsOneWidget);
    });

    testWidgets('the swap button inverts the conversion', (tester) async {
      await openTab(tester, 'CONVERT');
      await type(tester, 'Value', '100');
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      // 100 SM is 86.90 NM.
      expect(find.text('86.90 NM'), findsOneWidget);
    });

    testWidgets('temperature converts by scale and offset, not by ratio',
        (tester) async {
      // 100 C is 212 F. A ratio-only conversion would give 180.
      await openTab(tester, 'CONVERT');
      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      await type(tester, 'Value', '100');

      expect(find.text('212.00 °F'), findsOneWidget);
    });

    testWidgets('freezing converts to 32 F', (tester) async {
      await openTab(tester, 'CONVERT');
      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      await type(tester, 'Value', '0');

      expect(find.text('32.00 °F'), findsOneWidget);
    });

    testWidgets('the standard altimeter setting converts to 1013 hPa',
        (tester) async {
      await openTab(tester, 'CONVERT');
      await tester.tap(find.text('Pressure'));
      await tester.pumpAndSettle();
      await type(tester, 'Value', '29.92');

      expect(find.text('1,013.21 hPa'), findsOneWidget);
    });

    testWidgets('a gallon of avgas is 3.79 litres', (tester) async {
      await openTab(tester, 'CONVERT');
      await tester.tap(find.text('Volume'));
      await tester.pumpAndSettle();
      await type(tester, 'Value', '1');

      expect(find.text('3.79 L'), findsOneWidget);
    });
  });
}
