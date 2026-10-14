/// Field parsing and cross-field checks for the logbook entry form. Pure Dart.
library;

import 'logbook_entry.dart';

/// Result of reading one text field.
class Parsed<T> {
  final T? value;
  final String? error;
  const Parsed.ok(this.value) : error = null;
  const Parsed.err(this.error) : value = null;
  bool get ok => error == null;
}

/// Hours: empty means 0 (nothing logged in that column); "1.5", "0.0" and
/// "1,5" are accepted; negatives and text are refused.
Parsed<double> parseHours(String raw) {
  final s = raw.trim().replaceAll(',', '.');
  if (s.isEmpty) return const Parsed.ok(0);
  final v = double.tryParse(s);
  if (v == null || v.isNaN || v.isInfinite) {
    return const Parsed.err('Enter hours as a number, e.g. 1.3');
  }
  if (v < 0) return const Parsed.err('Hours cannot be negative');
  if (v > 24) return const Parsed.err('More than 24 hours in one entry');
  return Parsed.ok(v);
}

/// Counts (takeoffs, landings, approaches): whole numbers only, empty = 0.
Parsed<int> parseCount(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return const Parsed.ok(0);
  final v = int.tryParse(s);
  if (v == null) return const Parsed.err('Whole numbers only');
  if (v < 0) return const Parsed.err('Cannot be negative');
  if (v > 999) return const Parsed.err('Too large');
  return Parsed.ok(v);
}

/// Cross-field problems, keyed by the field they belong to.
Map<String, String> crossCheck(LogbookEntry e) {
  final errors = <String, String>{};
  if (e.totalTime <= 0) {
    errors['total'] = 'Total time is required';
  }
  void sub(String key, String label, double v) {
    if (v > e.totalTime + 1e-9) {
      errors[key] = '$label cannot exceed total time';
    }
  }

  sub('pic', 'PIC', e.picTime);
  sub('sic', 'SIC', e.sicTime);
  sub('dual', 'Dual received', e.dualReceived);
  sub('solo', 'Solo', e.soloTime);
  sub('cfi', 'CFI given', e.cfiGiven);
  sub('xc', 'Cross-country', e.crossCountry);
  sub('night', 'Night', e.night);
  sub('actual', 'Actual instrument', e.actualInstrument);
  sub('sim', 'Simulated instrument', e.simulatedInstrument);
  if (e.actualInstrument + e.simulatedInstrument > e.totalTime + 1e-9) {
    errors['sim'] = 'Instrument time cannot exceed total time';
  }
  if (e.dayFullStopLandings > e.dayLandings) {
    errors['dayFullStop'] = 'More full stops than day landings';
  }
  if (e.aircraftType.trim().isEmpty) {
    errors['type'] = 'Aircraft type is required';
  }
  if (e.categoryClass.trim().isEmpty) {
    errors['categoryClass'] = 'Category/class is required for currency';
  }
  return errors;
}
