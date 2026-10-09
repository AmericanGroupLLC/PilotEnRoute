/// Foldable / dual-screen layout tests.
///
/// The defining property of a folding phone is not one extra screen size — it
/// is that the window *changes size while the app is running*, and that it
/// takes aspect ratios no current iPhone has: near-square when unfolded, very
/// tall and narrow when folded. A layout that only ever sees 9:19.5 breaks
/// visibly the first time the user unfolds the device.
///
/// Apple ships no simulator for this, so these widget tests are the
/// verification. Each primary screen is pumped at the folded, unfolded,
/// landscape and mid-resize geometries and must produce no RenderFlex
/// overflow and no layout exception. The busiest screen is also pumped at a
/// 1.6x text scale, because a fold plus large type is where text layouts
/// actually break.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/services/aviation_api_service.dart';
import 'package:pilot_enroute/services/news_service.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/notification_service.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';
import 'package:pilot_enroute/services/flight_tracker_service.dart';
import 'package:pilot_enroute/services/flashcard_service.dart';
import 'package:pilot_enroute/services/weather_service.dart';

import 'package:pilot_enroute/screens/home_screen.dart';
import 'package:pilot_enroute/screens/weather_screen.dart';
import 'package:pilot_enroute/screens/news_screen.dart';
import 'package:pilot_enroute/screens/quiz_screen.dart';
import 'package:pilot_enroute/screens/airport_screen.dart';
import 'package:pilot_enroute/screens/glossary_screen.dart';
import 'package:pilot_enroute/screens/drone_screen.dart';
import 'package:pilot_enroute/screens/education_screen.dart';
import 'package:pilot_enroute/screens/endorsements_screen.dart';
import 'package:pilot_enroute/screens/career_screen.dart';
import 'package:pilot_enroute/screens/icara_screen.dart';
import 'package:pilot_enroute/screens/notifications_screen.dart';
import 'package:pilot_enroute/screens/checklist_screen.dart';
import 'package:pilot_enroute/screens/emergency_screen.dart';
import 'package:pilot_enroute/screens/profile_screen.dart';
import 'package:pilot_enroute/screens/flashcard_screen.dart';
import 'package:pilot_enroute/screens/exam_screen.dart';
import 'package:pilot_enroute/screens/flight_plan_screen.dart';
import 'package:pilot_enroute/screens/flight_tracker_screen.dart';
import 'package:pilot_enroute/screens/garmin_screen.dart';
import 'package:pilot_enroute/screens/alerts_screen.dart';
import 'package:pilot_enroute/screens/e6b_screen.dart';
import 'package:pilot_enroute/screens/fuel_screen.dart';
import 'package:pilot_enroute/screens/weight_balance_screen.dart';
import 'package:pilot_enroute/screens/regulations_screen.dart';

/// The geometries a folding iPhone actually presents, in logical pixels.
///
/// `folded` is the cover display: taller and narrower than any current phone.
/// `unfolded` is near-square (aspect ~0.87), which no iPhone has today.
/// `midResize` is a frame caught part-way through the unfold animation — the
/// framework really does lay out at those in-between widths.
const Map<String, Size> _foldGeometries = <String, Size>{
  'folded cover 360x840': Size(360, 840),
  'unfolded near-square 730x840': Size(730, 840),
  'unfolded landscape 840x730': Size(840, 730),
  'mid-resize 540x840': Size(540, 840),
  'smallest supported 320x690': Size(320, 690),
  // The same device turned on its side. A folded phone in landscape is the
  // shortest window the app will ever get.
  'folded landscape 840x360': Size(840, 360),
  'mid-resize landscape 840x540': Size(840, 540),
};

Widget _wrap(Widget screen, {double textScale = 1.0}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AviationApiService()),
      ChangeNotifierProvider(create: (_) => NewsService()),
      ChangeNotifierProvider(create: (_) => LogbookService()),
      ChangeNotifierProvider(create: (_) => NotificationService()),
      ChangeNotifierProvider(create: (_) => FlightPlanService()),
      ChangeNotifierProvider(create: (_) => FlightTrackerService()),
      ChangeNotifierProvider(create: (_) => FlashcardService()),
      ChangeNotifierProvider(create: (_) => WeatherService()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
      routes: {
        '/store': (_) => const Scaffold(body: Text('Store')),
        '/weather': (_) => const Scaffold(body: Text('Weather')),
        '/quiz': (_) => const Scaffold(body: Text('Quiz')),
        '/logbook': (_) => const Scaffold(body: Text('Logbook')),
        '/simulation': (_) => const Scaffold(body: Text('Simulation')),
        '/flashcards': (_) => const Scaffold(body: Text('Flashcards')),
        '/exam': (_) => const Scaffold(body: Text('Exam')),
        '/flight-tracker': (_) => const Scaffold(body: Text('Tracker')),
        '/flight-plan': (_) => const Scaffold(body: Text('Plan')),
        '/drone': (_) => const Scaffold(body: Text('Drone')),
        '/news': (_) => const Scaffold(body: Text('News')),
        '/airport': (_) => const Scaffold(body: Text('Airport')),
        '/glossary': (_) => const Scaffold(body: Text('Glossary')),
        '/education': (_) => const Scaffold(body: Text('Education')),
        '/checklist': (_) => const Scaffold(body: Text('Checklist')),
        '/emergency': (_) => const Scaffold(body: Text('Emergency')),
        '/endorsements': (_) => const Scaffold(body: Text('Endorsements')),
        '/career': (_) => const Scaffold(body: Text('Career')),
        '/icara': (_) => const Scaffold(body: Text('ICARA')),
        '/garmin': (_) => const Scaffold(body: Text('Garmin')),
        '/notifications': (_) => const Scaffold(body: Text('Notifications')),
        '/profile': (_) => const Scaffold(body: Text('Profile')),
      },
    ),
  );
}

/// Pumps until the tree is quiet.
///
/// `pumpAndSettle` alone cannot be used across the whole app: a screen that
/// drives a controller with `..repeat()` never settles. A
/// timeout there is not a layout failure, so it is swallowed — any real
/// build/layout exception is still recorded by the binding and is picked up by
/// `takeException()` below.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.paint,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Pumps [screen] at [size] and fails if the frame produced any exception.
/// RenderFlex overflow errors surface through `takeException()`.
Future<void> _expectNoOverflow(
  WidgetTester tester,
  Size size,
  String label,
  Widget screen, {
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(screen, textScale: textScale));
  await _settle(tester);

  expect(
    tester.takeException(),
    isNull,
    reason: '${screen.runtimeType} overflowed at $label '
        '(${size.width.toInt()}x${size.height.toInt()}, '
        'textScale ${textScale}x)',
  );
}

/// Registers the whole fold sweep for one screen.
void _foldSweep(String name, Widget Function() build) {
  group(name, () {
    _foldGeometries.forEach((label, size) {
      testWidgets('lays out at $label', (tester) async {
        await _expectNoOverflow(tester, size, label, build());
      });
    });
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('every primary screen survives a fold', () {
    _foldSweep('HomeScreen', () => const HomeScreen());
    _foldSweep('WeatherScreen', () => const WeatherScreen());
    _foldSweep('NewsScreen', () => const NewsScreen());
    _foldSweep('QuizScreen', () => const QuizScreen());
    _foldSweep('AirportScreen', () => const AirportScreen());
    _foldSweep('GlossaryScreen', () => const GlossaryScreen());
    _foldSweep('DroneScreen', () => const DroneScreen());
    _foldSweep('EducationScreen', () => const EducationScreen());
    _foldSweep('EndorsementsScreen', () => const EndorsementsScreen());
    _foldSweep('CareerScreen', () => const CareerScreen());
    _foldSweep('IcaraScreen', () => const IcaraScreen());
    _foldSweep('NotificationsScreen', () => const NotificationsScreen());
    _foldSweep('ChecklistScreen', () => const ChecklistScreen());
    _foldSweep('EmergencyScreen', () => const EmergencyScreen());
    _foldSweep('ProfileScreen', () => const ProfileScreen());
    _foldSweep('FlashcardScreen', () => const FlashcardScreen());
    _foldSweep('ExamScreen', () => const ExamScreen());
    _foldSweep('FlightPlanScreen', () => const FlightPlanScreen());
    _foldSweep('FlightTrackerScreen', () => const FlightTrackerScreen());
    _foldSweep('GarminScreen', () => const GarminScreen());
    _foldSweep('AlertsScreen', () => const AlertsScreen());
    _foldSweep('E6BScreen', () => const E6BScreen());
    _foldSweep('FuelScreen', () => const FuelScreen());
    _foldSweep('WeightBalanceScreen', () => const WeightBalanceScreen());
    // WindScreen builds a WebViewController in initState, which asserts
    // `WebViewPlatform.instance != null` — there is no platform
    // implementation in a widget test, so it cannot be pumped here at any
    // size. Its layout is a single full-bleed WebViewWidget under an AppBar.
    _foldSweep('RegulationsScreen', () => const RegulationsScreen());
  });

  // A fold plus large type is where text layouts actually break: the window
  // gets narrower *and* every string gets longer at the same time.
  group('large type on a folded window', () {
    final busiest = <String, Widget Function()>{
      'HomeScreen': () => const HomeScreen(),
      'QuizScreen': () => const QuizScreen(),
      'EmergencyScreen': () => const EmergencyScreen(),
      'ProfileScreen': () => const ProfileScreen(),
      'E6BScreen': () => const E6BScreen(),
      'WeightBalanceScreen': () => const WeightBalanceScreen(),
      'DroneScreen': () => const DroneScreen(),
      'CareerScreen': () => const CareerScreen(),
      'ExamScreen': () => const ExamScreen(),
    };

    busiest.forEach((name, build) {
      _foldGeometries.forEach((label, size) {
        testWidgets('$name at $label, 1.6x text', (tester) async {
          await _expectNoOverflow(tester, size, label, build(),
              textScale: 1.6);
        });
      });
    });
  });

  // The single most common foldable bug: a breakpoint read once at startup
  // does not update when the device unfolds. Resizing the same live tree
  // (rather than pumping a fresh one) is what catches it.
  group('resizing a live tree', () {
    testWidgets('HomeScreen reflows from folded to unfolded and back',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 840);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const HomeScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'folded');

      for (final size in const [
        Size(540, 840),
        Size(730, 840),
        Size(840, 730),
        Size(320, 690),
        Size(360, 840),
      ]) {
        tester.view.physicalSize = size;
        await _settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'HomeScreen overflowed after resizing to '
              '${size.width.toInt()}x${size.height.toInt()}',
        );
      }
    });
  });
}
