/// The logbook ledger: search, swipe-delete with undo, the in-list ad slot,
/// window totals and Copy as CSV.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/screens/logbook_screen.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/widgets/ad_banner_widget.dart';

import '../support/harness.dart';

LogbookEntry row(int day, String from, String to, {String tail = 'N35AB'}) =>
    LogbookEntry(
      date: DateTime(2026, 10, day),
      aircraftType: 'C172',
      tailNumber: tail,
      from: from,
      to: to,
      totalTime: 1.0,
      categoryClass: 'ASEL',
      dayTakeoffs: 1,
      dayLandings: 1,
    );

Future<Harness> open(WidgetTester tester, List<LogbookEntry> seed) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final h = Harness(logbook: LogbookService(store: MemoryLogbookStore(seed)));
  await h.logbook.init();
  await tester.pumpWidget(
      h.wrap(LogbookScreen(clock: () => DateTime(2026, 10, 14, 12))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

void main() {
  testWidgets('an empty logbook says so', (tester) async {
    await open(tester, const []);
    expect(find.textContaining('No flights logged yet'), findsOneWidget);
  });

  testWidgets('rows are grouped under a month header', (tester) async {
    await open(tester, [row(12, 'KPAO', 'KSQL'), row(2, 'KSQL', 'KHAF')]);
    expect(find.text('OCT 2026'), findsOneWidget);
    expect(find.text('KPAO → KSQL'), findsOneWidget);
    expect(find.text('KSQL → KHAF'), findsOneWidget);
  });

  testWidgets('search narrows the list by airport or tail', (tester) async {
    await open(tester, [
      row(12, 'KPAO', 'KSQL'),
      row(2, 'KSQL', 'KHAF', tail: 'N55PA'),
    ]);
    await tester.enterText(find.byKey(const Key('logbook-search')), 'khaf');
    await tester.pump();
    expect(find.text('KPAO → KSQL'), findsNothing);
    expect(find.text('KSQL → KHAF'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('logbook-search')), 'n35');
    await tester.pump();
    expect(find.text('KPAO → KSQL'), findsOneWidget);
    expect(find.text('KSQL → KHAF'), findsNothing);
    await tester.enterText(find.byKey(const Key('logbook-search')), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No flights match'), findsOneWidget);
  });

  testWidgets('swipe to delete, then Undo puts it back', (tester) async {
    final h = await open(tester, [row(12, 'KPAO', 'KSQL')]);
    await tester.drag(find.text('KPAO → KSQL'), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(h.logbook.entries, isEmpty);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(h.logbook.entries.single.from, 'KPAO');
    expect(find.text('KPAO → KSQL'), findsOneWidget);
  });

  testWidgets('one in-list ad slot after the 5th row, none before it',
      (tester) async {
    await open(tester, [for (var d = 1; d <= 4; d++) row(d, 'KPAO', 'KSQL')]);
    expect(find.byType(AdBannerWidget), findsNothing);
    await open(tester, [for (var d = 1; d <= 7; d++) row(d, 'KPAO', 'KSQL')]);
    expect(find.byType(AdBannerWidget), findsOneWidget);
    // It sits below the 5th row (the 5 newest are 7..3 Oct), above the 6th.
    final ad = tester.getTopLeft(find.byType(AdBannerWidget)).dy;
    final fifth = tester.getTopLeft(find.text('03\nOCT')).dy;
    final sixth = tester.getTopLeft(find.text('02\nOCT')).dy;
    expect(ad, greaterThan(fifth));
    expect(ad, lessThan(sixth));
  });

  testWidgets('still only one ad slot in a long logbook', (tester) async {
    await open(tester, [for (var d = 1; d <= 25; d++) row(d, 'KPAO', 'KSQL')]);
    expect(find.byType(AdBannerWidget, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Copy as CSV puts the whole logbook on the clipboard',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, [row(12, 'KPAO', 'KSQL'), row(2, 'KSQL', 'KHAF')]);
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy as CSV'));
    await tester.pumpAndSettle();
    expect(copied, isNotNull);
    final lines = copied!.split('\r\n').where((l) => l.isNotEmpty).toList();
    expect(lines, hasLength(3));
    expect(lines[1], startsWith('2026-10-02,C172,N35AB,ASEL'));
    expect(find.text('Copied 2 flights as CSV'), findsOneWidget);
  });

  testWidgets('totals tab shows 30/90/365 days and all time', (tester) async {
    await open(tester, [
      row(12, 'KPAO', 'KSQL'),
      LogbookEntry(
        date: DateTime(2026, 3, 1),
        aircraftType: 'C172',
        tailNumber: 'N1',
        from: 'KPAO',
        to: 'KPAO',
        totalTime: 2.0,
        categoryClass: 'ASEL',
      ),
    ]);
    await tester.tap(find.text('Totals'));
    await tester.pumpAndSettle();
    for (final w in ['30 days', '90 days', '365 days', 'All time']) {
      expect(find.text(w), findsOneWidget);
    }
    // Total row: 1.0 in 30 and 90 days, 3.0 in 365 days and all time.
    expect(find.text('1.0'), findsWidgets);
    expect(find.text('3.0'), findsNWidgets(2));
  });
}
