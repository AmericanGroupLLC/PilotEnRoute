// Smoke test: the real app widget builds with its default dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/main.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PilotEnRoute smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(PilotEnRouteApp(
        logbook: LogbookService(store: MemoryLogbookStore())));
    expect(find.byType(PilotEnRouteApp), findsOneWidget);
    expect(find.byType(RootGate), findsOneWidget);
  });
}
