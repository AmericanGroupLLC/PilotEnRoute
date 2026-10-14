/// The full-screen logbook entry: records what the legality engine needs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/screens/logbook_entry_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:pilot_enroute/widgets/ad_banner_widget.dart';

import '../support/harness.dart';

DateTime clock() => DateTime(2026, 10, 14, 9);

Future<Harness> open(WidgetTester tester,
    {LogbookEntry? existing, List<LogbookEntry> seed = const []}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final h = Harness(
    settings: SettingsStore(
        onboardingDone: true,
        profile: const PilotProfile(homeCategoryClass: 'ASEL')),
    logbook: LogbookService(store: MemoryLogbookStore(seed)),
  );
  await h.logbook.init();
  await tester.pumpWidget(h.wrap(Navigator(
    onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => LogbookEntryScreen(existing: existing, clock: clock)),
  )));
  await tester.pump();
  return h;
}

Future<void> type(WidgetTester t, String key, String value) async {
  await t.enterText(find.byKey(Key('entry-$key')), value);
}

String text(WidgetTester t, String key) =>
    t.widget<TextFormField>(find.byKey(Key('entry-$key'))).controller!.text;

void main() {
  testWidgets('a new entry defaults to today and to no landings',
      (tester) async {
    await open(tester);
    expect(find.text('14 Oct 2026'), findsOneWidget);
    // The old sheet hard-coded one day landing; nothing is pre-filled now.
    expect(text(tester, 'dayLdg'), isEmpty);
    expect(text(tester, 'total'), isEmpty);
  });

  testWidgets('a night currency flight is saved with every column the '
      'engine reads', (tester) async {
    final h = await open(tester);
    await type(tester, 'type', 'C172S');
    await type(tester, 'tail', 'n35ab');
    await type(tester, 'from', 'kpao');
    await type(tester, 'to', 'ksql');
    await type(tester, 'total', '1.4');
    await type(tester, 'pic', '1.4');
    await type(tester, 'night', '1.1');
    await type(tester, 'nightTo', '3');
    await type(tester, 'nightLdg', '3');
    await type(tester, 'remarks', 'Night pattern, 3 full stops');
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();

    final e = h.logbook.entries.single;
    expect(e.date, DateTime(2026, 10, 14));
    expect(e.tailNumber, 'N35AB');
    expect(e.from, 'KPAO');
    expect(e.categoryClass, 'ASEL');
    expect(e.totalTime, 1.4);
    expect(e.night, 1.1);
    expect(e.nightTakeoffs, 3);
    expect(e.nightLandings, 3);
    expect(e.dayLandings, 0);

    // And the engine now sees night currency from it.
    final r = const LegalityEngine().evaluate(
      entries: h.logbook.entries,
      profile: PilotProfile.empty,
      flight: PlannedFlight(
          date: DateTime(2026, 10, 20),
          categoryClass: 'ASEL',
          passengers: true,
          night: true),
    );
    expect(r.rule(RuleId.nightPassengers).state, RuleState.valid);
  });

  testWidgets('instrument tasks and checks are recorded', (tester) async {
    final h = await open(tester);
    await type(tester, 'type', 'C172');
    await type(tester, 'total', '1.5');
    await type(tester, 'sim', '1.2');
    await type(tester, 'approaches', '3');
    await tester.tap(find.text('IFR'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Holding procedures'));
    await tester.tap(
        find.widgetWithText(SwitchListTile, 'Intercepting & tracking courses'));
    await tester.tap(find.widgetWithText(
        SwitchListTile, 'Instrument proficiency check (61.57(d))'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();
    final e = h.logbook.entries.single;
    expect(e.approaches, 3);
    expect(e.holding, isTrue);
    expect(e.tracking, isTrue);
    expect(e.ipc, isTrue);
    expect(e.conditions, 'IFR');
    expect(e.simulatedInstrument, 1.2);
  });

  testWidgets('PIC longer than total is refused with the reason',
      (tester) async {
    final h = await open(tester);
    await type(tester, 'type', 'C172');
    await type(tester, 'total', '1.0');
    await type(tester, 'pic', '1.5');
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pump();
    expect(find.text('PIC cannot exceed total time'), findsOneWidget);
    expect(h.logbook.entries, isEmpty);
  });

  testWidgets('a fractional landing count cannot even be typed',
      (tester) async {
    await open(tester);
    await type(tester, 'dayLdg', '2.5');
    expect(text(tester, 'dayLdg'), '25');
  });

  testWidgets('text in an hours field is refused', (tester) async {
    final h = await open(tester);
    await type(tester, 'type', 'C172');
    await type(tester, 'total', 'abc');
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pump();
    expect(find.text('Enter hours as a number, e.g. 1.3'), findsOneWidget);
    expect(h.logbook.entries, isEmpty);
  });

  testWidgets('tailwheel reveals day full-stop landings', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('entry-dayFullStop')), findsNothing);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Tailwheel'));
    await tester.pump();
    expect(find.byKey(const Key('entry-dayFullStop')), findsOneWidget);
  });

  testWidgets('"Log again" copies the last aircraft and route, not the times',
      (tester) async {
    await open(tester, seed: [
      LogbookEntry(
        date: DateTime(2026, 10, 10),
        aircraftType: 'PA28',
        tailNumber: 'N55PA',
        from: 'KSQL',
        to: 'KHAF',
        route: 'SJC',
        totalTime: 1.3,
        categoryClass: 'ASEL',
      ),
    ]);
    await tester.tap(find.byKey(const Key('log-again')));
    await tester.pump();
    expect(text(tester, 'type'), 'PA28');
    expect(text(tester, 'tail'), 'N55PA');
    expect(text(tester, 'from'), 'KSQL');
    expect(text(tester, 'to'), 'KHAF');
    expect(text(tester, 'total'), isEmpty);
  });

  testWidgets('editing changes the entry in place', (tester) async {
    final seedEntry = LogbookEntry(
      id: 1,
      date: DateTime(2026, 10, 10),
      aircraftType: 'PA28',
      tailNumber: 'N55PA',
      from: 'KSQL',
      to: 'KHAF',
      totalTime: 1.3,
      categoryClass: 'ASEL',
      dayTakeoffs: 1,
      dayLandings: 1,
    );
    final h = await open(tester, seed: [seedEntry]);
    final existing = h.logbook.entries.single;
    await tester.pumpWidget(h.wrap(Navigator(
      key: const ValueKey('edit'),
      onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => LogbookEntryScreen(existing: existing, clock: clock)),
    )));
    await tester.pump();
    expect(find.text('Edit flight'), findsOneWidget);
    expect(text(tester, 'total'), '1.3');
    await type(tester, 'dayLdg', '3');
    await type(tester, 'dayTo', '3');
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();
    expect(h.logbook.entries, hasLength(1));
    expect(h.logbook.entries.single.dayLandings, 3);
  });

  testWidgets('no ad on the entry form', (tester) async {
    await open(tester);
    expect(find.byType(AdBannerWidget), findsNothing);
  });
}
