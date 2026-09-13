/// VFRMap sectional / IFR-low tiles are keyed by the FAA chart cycle date.
///
/// The date used to be a hard-coded constant, so every shipped build pointed
/// at the cycle that was current on the day it was written and started
/// serving 404s as soon as charts rolled over. These tests pin the rolling
/// derivation instead.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/map_screen.dart';

void main() {
  group('vfrmapCycleFor', () {
    test('the anchor date maps to itself', () {
      expect(vfrmapCycleFor(DateTime.utc(2025, 1, 16)), '20250116');
    });

    test('a date inside the first cycle still reads the anchor', () {
      expect(vfrmapCycleFor(DateTime.utc(2025, 2, 12)), '20250116');
    });

    test('the day the cycle turns over moves to the next tile set', () {
      // 2025-01-16 + 28 days.
      expect(vfrmapCycleFor(DateTime.utc(2025, 2, 13)), '20250213');
    });

    test('many cycles later it is still on a cycle boundary', () {
      final cycle = vfrmapCycleFor(DateTime.utc(2026, 9, 12));
      final date = DateTime.utc(
        int.parse(cycle.substring(0, 4)),
        int.parse(cycle.substring(4, 6)),
        int.parse(cycle.substring(6, 8)),
      );
      expect(date.difference(kChartCycleAnchor).inDays % kChartCycleDays, 0);
      // The current cycle must already have started and must not be stale by
      // more than one cycle.
      final age = DateTime.utc(2026, 9, 12).difference(date).inDays;
      expect(age, greaterThanOrEqualTo(0));
      expect(age, lessThan(kChartCycleDays));
    });

    test('a date before the anchor clamps rather than going backwards', () {
      expect(vfrmapCycleFor(DateTime.utc(2024, 6, 1)), '20250116');
    });

    test('a local-time argument is interpreted in UTC', () {
      final local = DateTime.utc(2025, 2, 13, 12).toLocal();
      expect(vfrmapCycleFor(local), '20250213');
    });

    test('the formatted value is always eight digits', () {
      for (var i = 0; i < 40; i++) {
        final d = kChartCycleAnchor.add(Duration(days: i * 28));
        expect(vfrmapCycleFor(d), matches(RegExp(r'^\d{8}$')));
      }
    });
  });
}
