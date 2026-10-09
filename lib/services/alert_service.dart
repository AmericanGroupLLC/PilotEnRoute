import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PilotEnRoute — Alerts Center service.
///
/// Manages configurable pilot [AlertRule]s and a rolling in-app [AlertItem]
/// feed, both persisted to [SharedPreferences]. Provides evaluators that run
/// only against real inputs (a loaded METAR, a runway and endurance the user
/// supplied, expiry dates the user stored). Categories with no live data
/// source (NOTAM, terrain, traffic, airspace, checklist) are reported as
/// "not evaluated" — no alert is ever generated from invented inputs.
///
/// Self-contained: owns its own [FlutterLocalNotificationsPlugin] instance so
/// it does NOT depend on the app's NotificationService, and requires no
/// provider registration (the owning screen holds an instance in its State).
class AlertService extends ChangeNotifier {
  // ── Persistence keys ────────────────────────────────────────────────────
  static const String _kRulesKey = 'alert_rules';
  static const String _kFeedKey = 'alert_feed';

  // Optional profile keys read by the expiry evaluators (written by ProfileScreen).
  static const String _kMedicalExpiryKey = 'profile_medical_expiry';
  static const String _kBfrExpiryKey = 'profile_bfr_expiry';

  static const int _maxFeedItems = 100;

  // ── Local notifications (own instance — independent of NotificationService) ─
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _notifReady = false;
  int _notifId = 70000; // rolling id space for alert notifications

  // ── State ────────────────────────────────────────────────────────────────
  final List<AlertRule> _rules = [];
  final List<AlertItem> _feed = [];
  bool _loaded = false;

  List<AlertRule> get rules => List.unmodifiable(_rules);
  List<AlertItem> get feed => List.unmodifiable(_feed);
  bool get isLoaded => _loaded;
  int get unacknowledgedCount => _feed.where((a) => !a.acknowledged).length;

  AlertRule? ruleFor(AlertCategory category) {
    for (final r in _rules) {
      if (r.category == category) return r;
    }
    return null;
  }

  bool isEnabled(AlertCategory category) => ruleFor(category)?.enabled ?? false;

  // ── Initialisation ─────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadFromPrefs();
    // Fire-and-forget notification init; feed works regardless of the result.
    unawaited(_ensureNotifications());
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _rules
        ..clear()
        ..addAll(_decodeRules(prefs.getString(_kRulesKey)));
      if (_rules.isEmpty) {
        _rules.addAll(AlertRule.defaults());
      } else {
        // Make sure every known category has a rule (forward compatibility).
        for (final c in AlertCategory.values) {
          if (_rules.every((r) => r.category != c)) {
            _rules.add(AlertRule.defaultFor(c));
          }
        }
      }

      _feed
        ..clear()
        ..addAll(_decodeFeed(prefs.getString(_kFeedKey))
            .where((a) => !_isLegacyInventedAlert(a)));
      _feed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      // Corrupt / unavailable storage — fall back to sane defaults.
      if (_rules.isEmpty) _rules.addAll(AlertRule.defaults());
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  List<AlertRule> _decodeRules(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => AlertRule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Alerts written by earlier versions from invented inputs: the labelled
  /// SAMPLE generators, the fixed "RWY 09" crosswind check, the fixed
  /// 50-minute fuel check and the descent checklist reminder. Dropped on load
  /// so a pilot never keeps seeing them.
  static bool _isLegacyInventedAlert(AlertItem a) {
    if (a.title.startsWith('SAMPLE')) return true;
    switch (a.category) {
      case AlertCategory.crosswind:
        return a.title.endsWith('— RWY 09');
      case AlertCategory.fuel:
        return a.message.startsWith('Endurance 50m vs');
      case AlertCategory.checklist:
        return a.title == 'Checklist reminder — Descent';
      default:
        return false;
    }
  }

  List<AlertItem> _decodeFeed(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => AlertItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kRulesKey,
        jsonEncode(_rules.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _persistFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kFeedKey,
        jsonEncode(_feed.map((a) => a.toJson()).toList()),
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  // ── Rule management ────────────────────────────────────────────────────────
  Future<void> setRuleEnabled(AlertCategory category, bool enabled) async {
    final i = _rules.indexWhere((r) => r.category == category);
    if (i == -1) return;
    _rules[i] = _rules[i].copyWith(enabled: enabled);
    notifyListeners();
    await _persistRules();
  }

  Future<void> updateRule(AlertRule updated) async {
    final i = _rules.indexWhere((r) => r.category == updated.category);
    if (i == -1) {
      _rules.add(updated);
    } else {
      _rules[i] = updated;
    }
    notifyListeners();
    await _persistRules();
  }

  // ── Feed management ────────────────────────────────────────────────────────
  Future<void> addAlert(AlertItem item) async {
    _feed.insert(0, item);
    if (_feed.length > _maxFeedItems) {
      _feed.removeRange(_maxFeedItems, _feed.length);
    }
    notifyListeners();
    await _persistFeed();
    if (item.severity == AlertSeverity.warning) {
      await _fireDeviceNotification(item);
    }
  }

  Future<void> acknowledge(String id) async {
    final i = _feed.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _feed[i] = _feed[i].copyWith(acknowledged: true);
    notifyListeners();
    await _persistFeed();
  }

  Future<void> acknowledgeAll() async {
    for (var i = 0; i < _feed.length; i++) {
      if (!_feed[i].acknowledged) {
        _feed[i] = _feed[i].copyWith(acknowledged: true);
      }
    }
    notifyListeners();
    await _persistFeed();
  }

  Future<void> removeAlert(String id) async {
    _feed.removeWhere((a) => a.id == id);
    notifyListeners();
    await _persistFeed();
  }

  Future<void> clearFeed() async {
    _feed.clear();
    notifyListeners();
    await _persistFeed();
  }

  // ── Device notifications (guarded, degrade gracefully) ──────────────────────
  Future<void> _ensureNotifications() async {
    if (_notifReady) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(initSettings);

      // Android 13+ runtime permission + channel (best effort).
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'pilot_alerts',
          'Pilot Alerts',
          description: 'Warning-severity pilot alerts from the Alerts Center',
          importance: Importance.high,
          playSound: true,
        ),
      );

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      _notifReady = true;
    } catch (_) {
      // Init/permission failure — the in-app feed still works.
      _notifReady = false;
    }
  }

  Future<void> _fireDeviceNotification(AlertItem item) async {
    try {
      if (!_notifReady) await _ensureNotifications();
      if (!_notifReady) return;
      await _plugin.show(
        _notifId++,
        item.title,
        item.message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pilot_alerts',
            'Pilot Alerts',
            channelDescription:
                'Warning-severity pilot alerts from the Alerts Center',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Never let a notification failure break the app.
    }
  }

  // ── Evaluators that CAN run now ─────────────────────────────────────────────

  /// Crosswind component vs the user's limit.
  ///
  /// [runwayHeadingDeg] is the runway's magnetic heading (0–360),
  /// [windDirDeg] the direction wind is coming FROM, [windSpeedKts] its speed.
  /// Returns the raised [AlertItem] (already pushed to the feed) or null when
  /// the category is disabled.
  Future<AlertItem?> evaluateCrosswind({
    required double runwayHeadingDeg,
    required double windDirDeg,
    required double windSpeedKts,
    String? runwayLabel,
  }) async {
    final rule = ruleFor(AlertCategory.crosswind);
    if (rule == null || !rule.enabled) return null;

    final limit = rule.crosswindLimitKts ?? 20;
    var angle = (windDirDeg - runwayHeadingDeg).abs() % 360;
    if (angle > 180) angle = 360 - angle;
    final crosswind = (windSpeedKts * math.sin(angle * math.pi / 180)).abs();
    final headwind = windSpeedKts * math.cos(angle * math.pi / 180);

    final AlertSeverity severity;
    final String verb;
    if (crosswind >= limit) {
      severity = AlertSeverity.warning;
      verb = 'exceeds';
    } else if (crosswind >= limit * 0.8) {
      severity = AlertSeverity.caution;
      verb = 'approaching';
    } else {
      severity = AlertSeverity.info;
      verb = 'within';
    }

    final rwy = runwayLabel ?? 'RWY ${runwayHeadingDeg.round()}°';
    final item = _mkItem(
      category: AlertCategory.crosswind,
      severity: severity,
      title: 'Crosswind ${crosswind.toStringAsFixed(0)} kt — $rwy',
      message:
          'Wind ${windDirDeg.round()}° @ ${windSpeedKts.round()} kt. '
          'Crosswind ${crosswind.toStringAsFixed(0)} kt (${headwind >= 0 ? 'head' : 'tail'}wind '
          '${headwind.abs().toStringAsFixed(0)} kt) $verb your ${limit.toStringAsFixed(0)} kt limit.',
    );
    await addAlert(item);
    return item;
  }

  /// Ceiling / visibility against the FAA flight-category thresholds.
  ///
  /// Driven by a real METAR (see [MetarData] on WeatherService); the caller
  /// passes the decoded values so this service stays free of HTTP. A null
  /// ceiling means "no ceiling reported", which is the unlimited case, and a
  /// null visibility is simply left out of the grading.
  ///
  /// Severity follows the categories a pilot already flies by:
  ///   LIFR / IFR -> warning, MVFR -> caution, VFR -> info.
  Future<AlertItem?> evaluateWeather({
    required String station,
    int? ceilingFt,
    double? visibilitySm,
  }) async {
    final rule = ruleFor(AlertCategory.weather);
    if (rule == null || !rule.enabled) return null;

    final category = flightCategoryFor(
      ceilingFt: ceilingFt,
      visibilitySm: visibilitySm,
    );

    final AlertSeverity severity;
    switch (category) {
      case 'LIFR':
      case 'IFR':
        severity = AlertSeverity.warning;
      case 'MVFR':
        severity = AlertSeverity.caution;
      default:
        severity = AlertSeverity.info;
    }

    final ceilingText =
        ceilingFt == null ? 'ceiling unlimited' : 'ceiling $ceilingFt ft';
    final visText = visibilitySm == null
        ? 'visibility not reported'
        : 'visibility ${_trimNum(visibilitySm)} sm';

    final item = _mkItem(
      category: AlertCategory.weather,
      severity: severity,
      title: '$station $category',
      message: '$ceilingText, $visText.',
    );
    await addAlert(item);
    return item;
  }

  /// FAA flight category from a ceiling (ft AGL) and visibility (statute
  /// miles). Either may be missing; a missing value cannot push the category
  /// down, so it is treated as unrestricted.
  static String flightCategoryFor({int? ceilingFt, double? visibilitySm}) {
    final c = ceilingFt ?? 1 << 20;
    final v = visibilitySm ?? double.infinity;
    if (c < 500 || v < 1) return 'LIFR';
    if (c < 1000 || v < 3) return 'IFR';
    if (c <= 3000 || v <= 5) return 'MVFR';
    return 'VFR';
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// Fuel endurance vs required reserve.
  Future<AlertItem?> evaluateFuel({
    required int enduranceMinutes,
    int? reserveMinutes,
  }) async {
    final rule = ruleFor(AlertCategory.fuel);
    if (rule == null || !rule.enabled) return null;

    final reserve = reserveMinutes ?? rule.fuelReserveMinutes ?? 45;
    final margin = enduranceMinutes - reserve;

    final AlertSeverity severity;
    final String title;
    if (margin <= 0) {
      severity = AlertSeverity.warning;
      title = 'Fuel below reserve';
    } else if (margin <= 15) {
      severity = AlertSeverity.caution;
      title = 'Fuel reserve marginal';
    } else {
      severity = AlertSeverity.info;
      title = 'Fuel reserve OK';
    }

    final item = _mkItem(
      category: AlertCategory.fuel,
      severity: severity,
      title: title,
      message:
          'Endurance ${enduranceMinutes}m vs ${reserve}m reserve — '
          '${margin >= 0 ? '+' : ''}${margin}m usable margin.',
    );
    await addAlert(item);
    return item;
  }

  /// Currency/medical expiry proximity. Reads a prefs date when [expiry] is
  /// omitted; returns null (nothing evaluated) when no date is stored.
  Future<AlertItem?> evaluateExpiry({
    required AlertCategory category,
    DateTime? expiry,
    String? label,
  }) async {
    assert(category == AlertCategory.medical ||
        category == AlertCategory.currency);
    final rule = ruleFor(category);
    if (rule == null || !rule.enabled) return null;

    final date = expiry ??
        await _readProfileDate(
          category == AlertCategory.medical
              ? _kMedicalExpiryKey
              : _kBfrExpiryKey,
        );
    if (date == null) return null;

    final warnDays = rule.daysBeforeExpiry ?? 30;
    final daysLeft = date.difference(DateTime.now()).inDays;
    final subject = label ??
        (category == AlertCategory.medical
            ? 'Medical certificate'
            : 'Flight review / currency');

    final AlertSeverity severity;
    final String title;
    if (daysLeft < 0) {
      severity = AlertSeverity.warning;
      title = '$subject EXPIRED';
    } else if (daysLeft <= warnDays) {
      severity = AlertSeverity.caution;
      title = '$subject expiring soon';
    } else {
      severity = AlertSeverity.info;
      title = '$subject current';
    }

    final item = _mkItem(
      category: category,
      severity: severity,
      title: title,
      message: daysLeft < 0
          ? 'Expired ${-daysLeft} day(s) ago (${_ymd(date)}).'
          : '$daysLeft day(s) remaining (expires ${_ymd(date)}), alert threshold '
              '$warnDays days.',
    );
    await addAlert(item);
    return item;
  }

  Future<DateTime?> _readProfileDate(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Categories the last [runChecksNow] could not evaluate, each with the
  /// reason (missing input or no data source). Shown instead of an alert.
  List<String> get lastNotEvaluated => List.unmodifiable(_lastNotEvaluated);
  List<String> _lastNotEvaluated = const [];

  /// Runs every evaluator that has real inputs. Returns the number of alerts
  /// pushed to the feed.
  ///
  /// - Weather is graded only from a supplied METAR ([metarStation] plus its
  ///   ceiling/visibility).
  /// - Crosswind runs only when both a reported wind and a runway the user
  ///   chose ([runwayHeadingDeg]) are supplied.
  /// - Fuel runs only when the user supplied [fuelEnduranceMinutes].
  /// - Medical / flight review run only from dates the user stored.
  /// - NOTAM, terrain, traffic, airspace and checklist have no live source
  ///   wired, so they are never alerted on.
  ///
  /// Everything skipped is listed in [lastNotEvaluated].
  Future<int> runChecksNow({
    String? metarStation,
    int? ceilingFt,
    double? visibilitySm,
    int? windDirDeg,
    int? windSpeedKts,
    double? runwayHeadingDeg,
    String? runwayLabel,
    int? fuelEnduranceMinutes,
  }) async {
    final before = _feed.length;
    final skipped = <String>[];

    if (windDirDeg != null && windSpeedKts != null && runwayHeadingDeg != null) {
      await evaluateCrosswind(
        runwayHeadingDeg: runwayHeadingDeg,
        windDirDeg: windDirDeg.toDouble(),
        windSpeedKts: windSpeedKts.toDouble(),
        runwayLabel: runwayLabel,
      );
    } else {
      skipped.add('Crosswind — not evaluated: needs a loaded METAR wind and a runway');
    }

    if (fuelEnduranceMinutes != null) {
      await evaluateFuel(enduranceMinutes: fuelEnduranceMinutes);
    } else {
      skipped.add('Fuel — not evaluated: enter your fuel endurance');
    }

    if (await evaluateExpiry(category: AlertCategory.medical) == null &&
        ruleFor(AlertCategory.medical)?.enabled == true) {
      skipped.add('Medical — not evaluated: set your medical expiry date in Profile');
    }
    if (await evaluateExpiry(category: AlertCategory.currency) == null &&
        ruleFor(AlertCategory.currency)?.enabled == true) {
      skipped.add('Flight review — not evaluated: set your flight review date in Profile');
    }

    if (metarStation != null && metarStation.isNotEmpty) {
      await evaluateWeather(
        station: metarStation,
        ceilingFt: ceilingFt,
        visibilitySm: visibilitySm,
      );
    } else {
      skipped.add('Weather — not evaluated: load a METAR in Weather first');
    }

    for (final c in const [
      AlertCategory.notam,
      AlertCategory.terrain,
      AlertCategory.traffic,
      AlertCategory.airspace,
      AlertCategory.checklist,
    ]) {
      skipped.add('${c.label} — not evaluated: no data source');
    }

    _lastNotEvaluated = skipped;
    notifyListeners();
    return _feed.length - before;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  AlertItem _mkItem({
    required AlertCategory category,
    required AlertSeverity severity,
    required String title,
    required String message,
  }) {
    final now = DateTime.now();
    return AlertItem(
      id: '${now.microsecondsSinceEpoch}_${category.name}',
      category: category,
      severity: severity,
      title: title,
      message: message,
      timestamp: now,
    );
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

/// Alert categories from the spec.
enum AlertCategory {
  weather,
  crosswind,
  fuel,
  currency,
  medical,
  notam,
  checklist,
  terrain,
  traffic,
  airspace,
}

extension AlertCategoryX on AlertCategory {
  String get label {
    switch (this) {
      case AlertCategory.weather:
        return 'Weather';
      case AlertCategory.crosswind:
        return 'Crosswind';
      case AlertCategory.fuel:
        return 'Fuel';
      case AlertCategory.currency:
        return 'Currency';
      case AlertCategory.medical:
        return 'Medical Expiry';
      case AlertCategory.notam:
        return 'NOTAM';
      case AlertCategory.checklist:
        return 'Checklist Reminder';
      case AlertCategory.terrain:
        return 'Terrain';
      case AlertCategory.traffic:
        return 'Traffic';
      case AlertCategory.airspace:
        return 'Airspace';
    }
  }

  static AlertCategory fromName(String? name) {
    return AlertCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => AlertCategory.weather,
    );
  }
}

enum AlertSeverity { info, caution, warning }

extension AlertSeverityX on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.info:
        return 'INFO';
      case AlertSeverity.caution:
        return 'CAUTION';
      case AlertSeverity.warning:
        return 'WARNING';
    }
  }

  static AlertSeverity fromName(String? name) {
    return AlertSeverity.values.firstWhere(
      (s) => s.name == name,
      orElse: () => AlertSeverity.info,
    );
  }
}

/// A configurable rule for one alert category.
class AlertRule {
  final AlertCategory category;
  final bool enabled;

  // Optional threshold parameters (only meaningful for some categories).
  final double? crosswindLimitKts; // crosswind
  final int? fuelReserveMinutes; // fuel
  final int? daysBeforeExpiry; // currency / medical

  const AlertRule({
    required this.category,
    required this.enabled,
    this.crosswindLimitKts,
    this.fuelReserveMinutes,
    this.daysBeforeExpiry,
  });

  AlertRule copyWith({
    bool? enabled,
    double? crosswindLimitKts,
    int? fuelReserveMinutes,
    int? daysBeforeExpiry,
  }) {
    return AlertRule(
      category: category,
      enabled: enabled ?? this.enabled,
      crosswindLimitKts: crosswindLimitKts ?? this.crosswindLimitKts,
      fuelReserveMinutes: fuelReserveMinutes ?? this.fuelReserveMinutes,
      daysBeforeExpiry: daysBeforeExpiry ?? this.daysBeforeExpiry,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'enabled': enabled,
        'crosswindLimitKts': crosswindLimitKts,
        'fuelReserveMinutes': fuelReserveMinutes,
        'daysBeforeExpiry': daysBeforeExpiry,
      };

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    final category = AlertCategoryX.fromName(json['category'] as String?);
    final defaults = AlertRule.defaultFor(category);
    return AlertRule(
      category: category,
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      crosswindLimitKts: (json['crosswindLimitKts'] as num?)?.toDouble() ??
          defaults.crosswindLimitKts,
      fuelReserveMinutes:
          (json['fuelReserveMinutes'] as num?)?.toInt() ??
              defaults.fuelReserveMinutes,
      daysBeforeExpiry:
          (json['daysBeforeExpiry'] as num?)?.toInt() ??
              defaults.daysBeforeExpiry,
    );
  }

  /// Whether this category exposes an editable numeric threshold.
  bool get hasThreshold =>
      category == AlertCategory.crosswind ||
      category == AlertCategory.fuel ||
      category == AlertCategory.currency ||
      category == AlertCategory.medical;

  static AlertRule defaultFor(AlertCategory category) {
    switch (category) {
      case AlertCategory.crosswind:
        return const AlertRule(
          category: AlertCategory.crosswind,
          enabled: true,
          crosswindLimitKts: 20,
        );
      case AlertCategory.fuel:
        return const AlertRule(
          category: AlertCategory.fuel,
          enabled: true,
          fuelReserveMinutes: 45,
        );
      case AlertCategory.currency:
        return const AlertRule(
          category: AlertCategory.currency,
          enabled: true,
          daysBeforeExpiry: 30,
        );
      case AlertCategory.medical:
        return const AlertRule(
          category: AlertCategory.medical,
          enabled: true,
          daysBeforeExpiry: 30,
        );
      default:
        return AlertRule(category: category, enabled: true);
    }
  }

  static List<AlertRule> defaults() =>
      AlertCategory.values.map(AlertRule.defaultFor).toList();
}

/// A single item in the rolling alert feed.
class AlertItem {
  final String id;
  final AlertCategory category;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool acknowledged;

  const AlertItem({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.acknowledged = false,
  });

  AlertItem copyWith({bool? acknowledged}) {
    return AlertItem(
      id: id,
      category: category,
      severity: severity,
      title: title,
      message: message,
      timestamp: timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'severity': severity.name,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'acknowledged': acknowledged,
      };

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      category: AlertCategoryX.fromName(json['category'] as String?),
      severity: AlertSeverityX.fromName(json['severity'] as String?),
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }
}
