/// Spec S1: progress toward 14 CFR 61.109(a) (private pilot, airplane
/// single-engine) from the student's own entries. Each test names the
/// paragraph it checks; the regulation text is quoted in
/// lib/core/legality/private_pilot_progress.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/private_pilot_progress.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';

final now = DateTime(2026, 10, 17, 12);

LogbookEntry e({
  DateTime? date,
  String cc = 'ASEL',
  double total = 1.0,
  double dual = 0,
  double solo = 0,
  double xc = 0,
  double night = 0,
  double sim = 0,
  double actual = 0,
  int nightTo = 0,
  int nightLdg = 0,
}) =>
    LogbookEntry(
      date: date ?? DateTime(2026, 9, 1),
      aircraftType: 'C172',
      tailNumber: 'N35AB',
      from: 'KPAO',
      to: 'KPAO',
      totalTime: total,
      categoryClass: cc,
      dualReceived: dual,
      soloTime: solo,
      crossCountry: xc,
      night: night,
      simulatedInstrument: sim,
      actualInstrument: actual,
      nightTakeoffs: nightTo,
      nightLandings: nightLdg,
    );

ProgressItem item(PrivatePilotProgress p, String cite, [String? title]) =>
    p.items.firstWhere((i) =>
        i.cite == cite && (title == null || i.title.contains(title)));

void main() {
  test('an empty logbook: nothing met, three items not tracked', () {
    final p = privatePilotProgress(entries: const [], now: now);
    expect(p.items, hasLength(14));
    expect(p.metCount, 0);
    expect(p.items.where((i) => !i.tracked), hasLength(3));
    expect(p.trackedItemsMet, isFalse);
  });

  test('61.109(a): 40 h of flight time from every entry; 20 h dual and 10 h '
      'solo from single-engine airplane entries', () {
    final p = privatePilotProgress(entries: [
      for (var i = 0; i < 20; i++) e(total: 1.0, dual: 1.0),
      for (var i = 0; i < 10; i++) e(total: 1.0, solo: 1.0),
      for (var i = 0; i < 10; i++) e(total: 1.0, cc: 'Glider'),
    ], now: now);
    expect(item(p, '61.109(a)', 'Flight time').logged, 40);
    expect(item(p, '61.109(a)', 'Flight time').met, isTrue);
    expect(item(p, '61.109(a)', 'instructor').met, isTrue);
    expect(item(p, '61.109(a)', 'Solo').met, isTrue);
    expect(item(p, '61.109(a)', 'Flight time').progressText, '40.0 of 40.0 h');
  });

  test('61.109(a): helicopter, AMEL and unclassed instruction does not count '
      'toward the 20 h or 10 h (areas of operation in 61.107(b)(1))', () {
    final p = privatePilotProgress(entries: [
      for (var i = 0; i < 12; i++) e(total: 1, dual: 1),
      for (var i = 0; i < 8; i++) e(cc: 'Rotorcraft helicopter', total: 1, dual: 1),
      e(cc: 'AMEL', total: 3, solo: 3),
      e(cc: '', total: 2, solo: 2),
    ], now: now);
    expect(item(p, '61.109(a)', 'instructor').logged, 12);
    expect(item(p, '61.109(a)', 'instructor').met, isFalse);
    expect(item(p, '61.109(a)', 'Solo').logged, 0);
    expect(item(p, '61.109(a)', 'Flight time').logged, 25);
  });

  test('61.109(a)(1): dual cross-country is capped at the dual time', () {
    final p = privatePilotProgress(
        entries: [e(total: 2.0, dual: 1.5, xc: 2.0)], now: now);
    expect(item(p, '61.109(a)(1)').logged, 1.5);
  });

  test('61.109(a)(1)-(3): only single-engine airplane entries count (ASEL '
      'and ASES, not AMEL)', () {
    final p = privatePilotProgress(entries: [
      e(cc: 'ASES', total: 2, dual: 2, xc: 2),
      e(cc: 'AMEL', total: 2, dual: 2, xc: 2, night: 2, sim: 2),
    ], now: now);
    expect(item(p, '61.109(a)(1)').logged, 2);
    expect(item(p, '61.109(a)(2)').logged, 0);
    expect(item(p, '61.109(a)(3)').logged, 0);
  });

  test('61.109(a)(2) and (2)(ii): night training hours and 10 night '
      'takeoffs / full-stop landings from dual entries only', () {
    final p = privatePilotProgress(entries: [
      e(total: 1.5, dual: 1.5, night: 1.5, nightTo: 5, nightLdg: 5),
      e(total: 1.5, dual: 1.5, night: 1.5, nightTo: 5, nightLdg: 5),
      e(total: 1.0, solo: 1.0, night: 1.0, nightTo: 3, nightLdg: 3),
    ], now: now);
    expect(item(p, '61.109(a)(2)').logged, 3.0);
    expect(item(p, '61.109(a)(2)').met, isTrue);
    expect(item(p, '61.109(a)(2)(ii)', 'takeoffs').logged, 10);
    expect(item(p, '61.109(a)(2)(ii)', 'landings').logged, 10);
    expect(item(p, '61.109(a)(2)(ii)', 'landings').met, isTrue);
  });

  test('61.109(a)(3): simulated and actual instrument both count as '
      'training, capped at dual', () {
    final p = privatePilotProgress(
        entries: [e(total: 1.5, dual: 1.0, sim: 0.8, actual: 0.4)], now: now);
    expect(item(p, '61.109(a)(3)').logged, 1.0);
  });

  test('61.109(a)(4): dual in the preceding 2 calendar months, counted for a '
      'test this month (from 1 Aug for October)', () {
    final p = privatePilotProgress(entries: [
      e(date: DateTime(2026, 7, 31), total: 2, dual: 2),
      e(date: DateTime(2026, 8, 1), total: 1.5, dual: 1.5),
      e(date: DateTime(2026, 10, 16), total: 1.5, dual: 1.5),
      e(date: DateTime(2026, 10, 18), total: 1, dual: 1), // after now
    ], now: now);
    expect(item(p, '61.109(a)(4)').logged, 3.0);
    expect(item(p, '61.109(a)(4)').met, isTrue);
  });

  test('61.109(a)(5) and (5)(i): single-engine solo, and solo cross-country '
      'capped at the solo time', () {
    final p = privatePilotProgress(entries: [
      e(total: 6, solo: 6, xc: 6),
      e(total: 4, solo: 3, xc: 4, dual: 0),
      e(cc: 'AMEL', total: 2, solo: 2, xc: 2),
    ], now: now);
    expect(item(p, '61.109(a)(5)').logged, 9);
    expect(item(p, '61.109(a)(5)(i)').logged, 9);
    expect(item(p, '61.109(a)(5)(i)').met, isTrue);
    expect(item(p, '61.109(a)(5)').met, isFalse);
    expect(item(p, '61.109(a)(5)').remaining, 1);
  });

  test('an entry with both dual and solo is not split: its XC/night/'
      'instrument time counts nowhere and is reported', () {
    final p = privatePilotProgress(entries: [
      e(total: 2, dual: 1, solo: 1, xc: 2, night: 1),
      e(total: 1, dual: 0.5, solo: 0.5, nightTo: 2, nightLdg: 2),
      e(total: 1, dual: 0.5, solo: 0.5), // no split data, not reported
    ], now: now);
    expect(p.mixedEntries, 2);
    expect(item(p, '61.109(a)(2)(ii)', 'landings').logged, 0);
    expect(item(p, '61.109(a)(1)').logged, 0);
    expect(item(p, '61.109(a)(5)(i)').logged, 0);
    // Totals still count them.
    expect(item(p, '61.109(a)', 'instructor').logged, 2.0);
    expect(item(p, '61.109(a)(5)').logged, 2.0);
  });

  test('entries with no category/class count toward totals only', () {
    final p = privatePilotProgress(
        entries: [e(cc: '', total: 2, dual: 2, xc: 2)], now: now);
    expect(p.unclassedEntries, 1);
    expect(item(p, '61.109(a)', 'Flight time').logged, 2);
    expect(item(p, '61.109(a)(1)').logged, 0);
  });

  test('(2)(i), (5)(ii) and (5)(iii) are never shown as met: the logbook '
      'has no distances or tower status', () {
    final p = privatePilotProgress(entries: [
      for (var i = 0; i < 60; i++)
        e(total: 2, dual: 1, xc: 1, night: 1, sim: 1, nightTo: 1, nightLdg: 1),
      for (var i = 0; i < 20; i++) e(total: 1, solo: 1, xc: 1),
    ], now: now);
    for (final cite in ['61.109(a)(2)(i)', '61.109(a)(5)(ii)', '61.109(a)(5)(iii)']) {
      final i = item(p, cite);
      expect(i.tracked, isFalse, reason: cite);
      expect(i.met, isFalse, reason: cite);
      expect(i.progressText, 'Not tracked');
    }
    expect(p.trackedItemsMet, isTrue);
    expect(p.metCount, 11);
  });
}
