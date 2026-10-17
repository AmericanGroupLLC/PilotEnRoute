/// Sunrise and sunset on the device, for the 61.57(b) night-currency window
/// ("the period beginning 1 hour after sunset and ending 1 hour before
/// sunrise"). Pure Dart; no network.
///
/// The equations are NOAA's "General Solar Position Calculations" (NOAA
/// Global Monitoring Division): the fractional-year series for the equation
/// of time and the solar declination, and the hour angle for a zenith of
/// 90.833° (refraction plus the solar disc). They are good to a minute or
/// two at mid latitudes, which is why the Go Card says "about", and drift at
/// high latitude, so no window is shown above [kMaxSolarLatitude]. Tested
/// against US Naval Observatory times (test/core/solar_test.dart).
library;

import 'dart:math' as math;

import '../legality/date_text.dart';

class SunTimes {
  /// Null when the sun does not rise or set that day (polar day or night).
  final DateTime? sunriseUtc;
  final DateTime? sunsetUtc;

  /// The sun stays above the horizon all day.
  final bool alwaysUp;

  /// The sun stays below the horizon all day.
  final bool alwaysDown;

  const SunTimes({
    this.sunriseUtc,
    this.sunsetUtc,
    this.alwaysUp = false,
    this.alwaysDown = false,
  });
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Sunrise and sunset for the calendar day [date] at [lat]/[lon] (degrees,
/// north and east positive). Only the year, month and day of [date] are used:
/// the events returned are the ones around local solar noon of that day, so
/// a western-hemisphere sunset can fall on the next UTC date.
SunTimes sunTimes({
  required DateTime date,
  required double lat,
  required double lon,
}) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final dayOfYear = day.difference(DateTime.utc(date.year)).inDays + 1;
  final daysInYear =
      DateTime.utc(date.year + 1).difference(DateTime.utc(date.year)).inDays;

  // Fractional year at local solar noon (UTC hour 12 - lon/15).
  final noonUtcHour = 12 - lon / 15;
  final g = 2 * math.pi / daysInYear * (dayOfYear - 1 + (noonUtcHour - 12) / 24);

  final eqTimeMin = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);

  final phi = _rad(lat);
  final cosHa = math.cos(_rad(90.833)) / (math.cos(phi) * math.cos(decl)) -
      math.tan(phi) * math.tan(decl);
  if (cosHa < -1) return const SunTimes(alwaysUp: true);
  if (cosHa > 1) return const SunTimes(alwaysDown: true);
  final ha = _deg(math.acos(cosHa));

  DateTime at(double minutes) =>
      day.add(Duration(seconds: (minutes * 60).round()));
  return SunTimes(
    sunriseUtc: at(720 - 4 * (lon + ha) - eqTimeMin),
    sunsetUtc: at(720 - 4 * (lon - ha) - eqTimeMin),
  );
}

/// Above this latitude the short NOAA series drifts (24 min against USNO at
/// 78°N in testing), and polar day/night make the window ill-defined, so no
/// window is shown there.
const double kMaxSolarLatitude = 66.0;

/// The 61.57(b) window that starts on the evening of [date]: from 1 h after
/// that day's sunset to 1 h before the next day's sunrise.
class NightWindow {
  /// The calendar day whose evening the window starts on.
  final DateTime? date;
  final DateTime? startUtc;
  final DateTime? endUtc;

  /// Why there is no window (polar day/night, latitude, under 2 h of dark).
  final String? problem;

  const NightWindow({this.date, this.startUtc, this.endUtc, this.problem});
}

NightWindow nightCurrencyWindow({
  required DateTime date,
  required double lat,
  required double lon,
}) {
  final day = DateTime(date.year, date.month, date.day);
  if (lat.abs() > kMaxSolarLatitude) {
    return NightWindow(
        date: day,
        problem: 'Not worked out above ${kMaxSolarLatitude.round()}° '
            'latitude. Use an official sunrise/sunset source.');
  }
  final today = sunTimes(date: day, lat: lat, lon: lon);
  final next = sunTimes(
      date: DateTime(day.year, day.month, day.day + 1), lat: lat, lon: lon);
  if (today.sunsetUtc == null || next.sunriseUtc == null) {
    return NightWindow(
        date: day, problem: 'The sun does not set and rise again here that '
            'night.');
  }
  final start = today.sunsetUtc!.add(const Duration(hours: 1));
  final end = next.sunriseUtc!.subtract(const Duration(hours: 1));
  if (!start.isBefore(end)) {
    return NightWindow(
        date: day,
        problem: 'No 61.57(b) night that day: the sun is down for less than '
            '2 hours.');
  }
  return NightWindow(date: day, startUtc: start, endUtc: end);
}

/// The window a flight departing at [departure] (device local time) falls
/// in or comes before: an early-morning departure is still inside the
/// previous evening's window, so that one is returned.
NightWindow nightWindowForDeparture({
  required DateTime departure,
  required double lat,
  required double lon,
}) {
  final previous = nightCurrencyWindow(
      date: DateTime(departure.year, departure.month, departure.day - 1),
      lat: lat,
      lon: lon);
  final at = departure.toUtc();
  if (previous.endUtc != null && at.isBefore(previous.endUtc!)) {
    return previous;
  }
  return nightCurrencyWindow(date: departure, lat: lat, lon: lon);
}

/// "Night for passenger currency (61.57(b)) at KPAO on 21 Jun: about 04:32Z
/// to 11:47Z. ..." [local] adds the device's own clock time after each Zulu
/// time when given. The date is the evening the window starts on.
String nightWindowLine({
  required String station,
  required NightWindow window,
  String Function(DateTime utc)? local,
}) {
  final head = 'Night for passenger currency (61.57(b)) at $station';
  if (window.problem != null) return '$head: ${window.problem}';
  String t(DateTime u) => local == null
      ? zuluTime(u)
      : '${zuluTime(u)} (${local(u)} your time)';
  final d = window.date!;
  return '$head, evening of ${dayMonth(d, reference: d)}: about '
      '${t(window.startUtc!)} to ${t(window.endUtc!)}. That is 1 h after '
      'sunset to 1 h before sunrise.';
}
