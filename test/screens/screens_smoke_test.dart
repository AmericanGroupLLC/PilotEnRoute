/// Smoke tests — verify every screen renders without crashing.
/// These tests do NOT require a real device or network connection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/services/aviation_api_service.dart';
import 'package:pilot_enroute/services/news_service.dart';
import 'package:pilot_enroute/services/premium_service.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/notification_service.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';
import 'package:pilot_enroute/services/flight_tracker_service.dart';
import 'package:pilot_enroute/services/flashcard_service.dart';
import 'package:pilot_enroute/services/weather_service.dart';

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
import 'package:pilot_enroute/screens/premium_screen.dart';
import 'package:pilot_enroute/screens/flashcard_screen.dart';
import 'package:pilot_enroute/screens/exam_screen.dart';
import 'package:pilot_enroute/screens/logbook_screen.dart';
import 'package:pilot_enroute/screens/flight_plan_screen.dart';
import 'package:pilot_enroute/screens/flight_tracker_screen.dart';
import 'package:pilot_enroute/screens/garmin_screen.dart';

Widget buildProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AviationApiService()),
      ChangeNotifierProvider(create: (_) => NewsService()),
      // PremiumService is a singleton — use .value to avoid disposal issues
      ChangeNotifierProvider<PremiumService>.value(value: PremiumService()),
      ChangeNotifierProvider(create: (_) => LogbookService()),
      ChangeNotifierProvider(create: (_) => NotificationService()),
      ChangeNotifierProvider(create: (_) => FlightPlanService()),
      ChangeNotifierProvider(create: (_) => FlightTrackerService()),
      ChangeNotifierProvider(create: (_) => FlashcardService()),
      ChangeNotifierProvider(create: (_) => WeatherService()),
    ],
    child: MaterialApp(
      home: child,
      routes: {
        '/premium': (_) => const Scaffold(body: Text('Premium')),
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

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Screen Smoke Tests — All screens render without crashing', () {
    Future<void> smokeTest(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(buildProviders(screen));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    }

    testWidgets('WeatherScreen renders', (t) async => smokeTest(t, const WeatherScreen()));
    testWidgets('NewsScreen renders', (t) async => smokeTest(t, const NewsScreen()));
    testWidgets('QuizScreen renders', (t) async => smokeTest(t, const QuizScreen()));
    testWidgets('AirportScreen renders', (t) async => smokeTest(t, const AirportScreen()));
    testWidgets('GlossaryScreen renders', (t) async => smokeTest(t, const GlossaryScreen()));
    testWidgets('DroneScreen renders', (t) async => smokeTest(t, const DroneScreen()));
    testWidgets('EducationScreen renders', (t) async => smokeTest(t, const EducationScreen()));
    testWidgets('EndorsementsScreen renders', (t) async => smokeTest(t, const EndorsementsScreen()));
    testWidgets('CareerScreen renders', (t) async => smokeTest(t, const CareerScreen()));
    testWidgets('IcaraScreen renders', (t) async => smokeTest(t, const IcaraScreen()));
    testWidgets('NotificationsScreen renders', (t) async => smokeTest(t, const NotificationsScreen()));
    testWidgets('ChecklistScreen renders', (t) async => smokeTest(t, const ChecklistScreen()));
    testWidgets('EmergencyScreen renders', (t) async => smokeTest(t, const EmergencyScreen()));
    testWidgets('ProfileScreen renders', (t) async => smokeTest(t, const ProfileScreen()));
    testWidgets('PremiumScreen renders', (t) async => smokeTest(t, const PremiumScreen()));
    testWidgets('FlashcardScreen renders', (t) async => smokeTest(t, const FlashcardScreen()));
    testWidgets('ExamScreen renders', (t) async => smokeTest(t, const ExamScreen()));
    // LogbookScreen uses sqflite which requires a real device/emulator — tested via integration tests
    testWidgets('LogbookScreen renders', (t) async => smokeTest(t, const LogbookScreen()),
        skip: true); // sqflite requires device/emulator — run as integration test
    testWidgets('FlightPlanScreen renders', (t) async => smokeTest(t, const FlightPlanScreen()));
    testWidgets('FlightTrackerScreen renders', (t) async => smokeTest(t, const FlightTrackerScreen()));
    testWidgets('GarminScreen renders', (t) async => smokeTest(t, const GarminScreen()));
  });
}
