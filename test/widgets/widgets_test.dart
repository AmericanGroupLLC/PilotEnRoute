import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilot_enroute/services/premium_service.dart';
import 'package:pilot_enroute/widgets/module_card.dart';
import 'package:pilot_enroute/widgets/premium_gate.dart';
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

  group('PremiumGate widget', () {
    testWidgets('renders without crashing for free users', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'is_premium': false});
      // Use the singleton directly without calling dispose
      await tester.pumpWidget(
        ChangeNotifierProvider<PremiumService>.value(
          value: PremiumService(),
          child: MaterialApp(
            home: const Scaffold(
              body: PremiumGate(
                feature: 'locked_feature',
                title: 'Locked Feature',
                description: 'Upgrade to unlock this locked feature.',
                child: Text('Locked Content'),
              ),
            ),
            routes: {
              '/premium': (_) => const Scaffold(body: Text('Premium Screen')),
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('PremiumGate renders for free users without crash', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'is_premium': false});
      await tester.pumpWidget(
        ChangeNotifierProvider<PremiumService>.value(
          value: PremiumService(),
          child: MaterialApp(
            home: const Scaffold(
              body: PremiumGate(
                feature: 'logbook_export',
                title: 'Logbook Export',
                description: 'Export your logbook to PDF.',
                child: Icon(Icons.download),
              ),
            ),
            routes: {
              '/premium': (_) => const Scaffold(body: Text('Premium Screen')),
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });
  });
}
