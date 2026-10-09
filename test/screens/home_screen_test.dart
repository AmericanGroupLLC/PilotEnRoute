import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilot_enroute/services/aviation_api_service.dart';
import 'package:pilot_enroute/services/news_service.dart';
import 'package:pilot_enroute/services/weather_service.dart';
import 'package:pilot_enroute/screens/home_screen.dart';

Widget buildTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AviationApiService>(create: (_) => AviationApiService()),
      ChangeNotifierProvider<NewsService>(create: (_) => NewsService()),
      ChangeNotifierProvider<WeatherService>(create: (_) => WeatherService()),
    ],
    child: MaterialApp(
      home: child,
      routes: {
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
        '/store': (_) => const Scaffold(body: Text('Store')),
      },
    ),
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeScreen', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('has bottom navigation bar', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('has app bar', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppBar), findsAtLeastNWidgets(1));
    });

    testWidgets('displays module grid cards', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      // Should have multiple module cards in the grid
      expect(find.byType(GridView), findsAtLeastNWidgets(1));
    });
  });
}
