import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilot_enroute/widgets/module_card.dart';
import 'package:pilot_enroute/screens/home_screen.dart' show ModuleData;

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ModuleCard widget', () {
    testWidgets('renders with title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: ModuleCard(
              data: ModuleData(
                title: 'Test Module',
                icon: Icons.flight,
                color: Colors.blue,
                route: '/weather',
              ),
            ),
          ),
          routes: {
            '/weather': (_) => const Scaffold(body: Text('Weather')),
          },
        ),
      );
      expect(find.text('Test Module'), findsOneWidget);
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('renders with badge when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: ModuleCard(
              data: ModuleData(
                title: 'Premium Module',
                icon: Icons.star,
                color: Colors.amber,
                route: '/premium',
                badge: 'PRO',
              ),
            ),
          ),
          routes: {
            '/premium': (_) => const Scaffold(body: Text('Premium')),
          },
        ),
      );
      expect(find.text('Premium Module'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('tapping navigates to route', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: ModuleCard(
              data: ModuleData(
                title: 'Weather',
                icon: Icons.cloud,
                color: Colors.blue,
                route: '/weather',
              ),
            ),
          ),
          routes: {
            '/weather': (_) => const Scaffold(body: Text('Weather Screen')),
          },
        ),
      );
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('Weather Screen'), findsOneWidget);
    });
  });
}
