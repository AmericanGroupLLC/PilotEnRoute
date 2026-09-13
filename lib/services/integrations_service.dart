import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// PilotEnRoute — Integrations Hub
/// ============================================================================
///
/// This service defines a clean adapter architecture for connecting the app to
/// external hardware and third-party systems (ADS-B receivers, avionics,
/// simulators, wearables and flight-data providers).
///
/// HONESTY POLICY:
/// Nothing here fakes a connection. Every hardware/SDK integration is provided
/// as a documented STUB whose `connect()` returns `false` with a clear
/// "not configured" status. The only integrations that perform real work are
/// the local data import/export helpers, which operate on data already stored
/// on device (e.g. saved flight plans in SharedPreferences).
///
/// Each stub carries a `// TODO(...)` marker describing exactly what real
/// implementation would require (SDK, protocol, backend or companion app).
/// ============================================================================

/// High-level grouping used by the UI to lay out integrations in sections.
enum IntegrationCategory {
  adsbReceiver,
  avionics,
  simulator,
  wearable,
  dataImportExport,
}

extension IntegrationCategoryLabel on IntegrationCategory {
  String get label {
    switch (this) {
      case IntegrationCategory.adsbReceiver:
        return 'ADS-B Receiver';
      case IntegrationCategory.avionics:
        return 'Avionics';
      case IntegrationCategory.simulator:
        return 'Simulator';
      case IntegrationCategory.wearable:
        return 'Wearable';
      case IntegrationCategory.dataImportExport:
        return 'Data Import/Export';
    }
  }
}

/// Immutable descriptor of an integration surfaced in the hub.
///
/// Runtime state (whether an adapter is actually connected and its human
/// readable status) is derived from the adapter, not stored optimistically.
class Integration {
  final String id;
  final String name;
  final IntegrationCategory category;
  final String vendor;

  /// Whether the underlying adapter currently reports a live connection.
  final bool connected;

  /// Short human-readable status shown in the status pill / card subtitle.
  final String statusText;

  /// A longer explanation of what is required to enable this integration.
  /// Shown in the details bottom sheet.
  final String requirement;

  /// Optional vendor URL for "learn more" links (guarded with url_launcher).
  final String? vendorUrl;

  const Integration({
    required this.id,
    required this.name,
    required this.category,
    required this.vendor,
    required this.connected,
    required this.statusText,
    required this.requirement,
    this.vendorUrl,
  });

  Integration copyWith({
    bool? connected,
    String? statusText,
  }) {
    return Integration(
      id: id,
      name: name,
      category: category,
      vendor: vendor,
      connected: connected ?? this.connected,
      statusText: statusText ?? this.statusText,
      requirement: requirement,
      vendorUrl: vendorUrl,
    );
  }
}

/// Clean adapter contract every integration implements.
///
/// A real adapter would open a socket / BLE session / SDK handle in
/// [connect], expose live telemetry via [dataStream] and tear down in
/// [disconnect]. Stub adapters implement this contract honestly by refusing
/// to connect until the real transport is wired up.
abstract class IntegrationAdapter {
  /// Attempts to establish a live connection.
  ///
  /// Returns `true` only when a genuine connection is established. Stub
  /// adapters MUST return `false` — never a fabricated success.
  Future<bool> connect();

  /// Tears down any live connection. Safe to call when not connected.
  Future<void> disconnect();

  /// Live telemetry stream once connected, or `null` when unavailable.
  Stream<dynamic>? get dataStream;

  /// Human-readable status describing the current adapter state.
  String get statusText;

  /// Whether the adapter currently holds a live connection.
  bool get isConnected;
}

/// Base class for the not-yet-wired hardware/SDK adapters.
///
/// Provides the honest default behaviour: connect fails with a clear
/// "not configured" status, there is no data stream, and disconnect is a
/// no-op. Concrete stubs only customise the status message.
abstract class StubAdapter implements IntegrationAdapter {
  /// Message explaining why the adapter cannot connect yet.
  final String notConfiguredStatus;

  StubAdapter(this.notConfiguredStatus);

  @override
  bool get isConnected => false;

  @override
  String get statusText => notConfiguredStatus;

  @override
  Stream<dynamic>? get dataStream => null;

  @override
  Future<bool> connect() async {
    // Intentionally never fakes success. The real transport is not wired.
    return false;
  }

  @override
  Future<void> disconnect() async {
    // No live resources to release for a stub.
  }
}

// ---------------------------------------------------------------------------
// ADS-B In receivers (Stratus, Sentry, Garmin GDL).
// ---------------------------------------------------------------------------

/// Stub for portable ADS-B In receivers (Stratus, Sentry, Garmin GDL series).
///
/// TODO(adsb): add flutter_blue_plus / wifi socket to receive GDL90.
/// Real implementation: most portable receivers broadcast GDL90 frames over
/// a Wi-Fi UDP socket (typically the phone joins the receiver's SoftAP and
/// listens on port 4000). Parse GDL90 heartbeat, ownship, traffic and
/// weather (FIS-B) messages and push decoded objects onto [dataStream].
class AdsbReceiverAdapter extends StubAdapter {
  AdsbReceiverAdapter()
      : super('Requires ADS-B receiver + GDL90 socket — not configured');
}

// ---------------------------------------------------------------------------
// Panel avionics (Garmin, Dynon, Avidyne).
// ---------------------------------------------------------------------------

/// Stub for panel-mounted / portable avionics (Garmin, Dynon, Avidyne).
///
/// TODO(avionics): integrate vendor Connext / SkyView / IFD Connect SDKs.
/// Real implementation: pair over the vendor's wireless gateway (e.g. Garmin
/// Connext via Bluetooth/Wi-Fi) and exchange flight plans, GPS position and
/// traffic using the vendor's proprietary SDK/protocol.
class AvionicsAdapter extends StubAdapter {
  AvionicsAdapter()
      : super('Requires avionics SDK / wireless gateway — not configured');
}

// ---------------------------------------------------------------------------
// Flight simulators (X-Plane, MSFS, Infinite Flight, Prepar3D).
// ---------------------------------------------------------------------------

/// Stub for flight simulators (X-Plane, MSFS, Infinite Flight, Prepar3D).
///
/// TODO(sim): UDP GPS stream ingestion.
/// Real implementation: bind a UDP socket and consume the sim's GPS/NMEA or
/// native output (X-Plane data output, MSFS SimConnect bridge, Infinite
/// Flight Connect API) then feed position/attitude onto [dataStream].
class SimulatorAdapter extends StubAdapter {
  SimulatorAdapter()
      : super('Requires simulator UDP/GPS output — not configured');
}

// ---------------------------------------------------------------------------
// Wearables (Apple Watch, Garmin).
// ---------------------------------------------------------------------------

/// Stub for wearables (Apple Watch, Garmin wearables).
///
/// TODO(watch): companion app / WatchConnectivity.
/// Real implementation: build a watchOS companion (WatchConnectivity) or a
/// Garmin Connect IQ app and bridge session/heart-rate/glance data to the
/// phone over the platform channel, exposing it via [dataStream].
class WearableAdapter extends StubAdapter {
  WearableAdapter()
      : super('Requires companion watch app — not configured');
}

// ---------------------------------------------------------------------------
// Data import/export (ForeFlight, CloudAhoy, FlySto) — REAL local actions.
// ---------------------------------------------------------------------------

/// Result of a real export action.
class ExportResult {
  final bool success;
  final String message;

  /// Shareable payload (e.g. text / GPX-like content) when [success].
  final String? content;

  const ExportResult({
    required this.success,
    required this.message,
    this.content,
  });
}

/// Adapter for third-party flight-data services (ForeFlight, CloudAhoy,
/// FlySto). Live account sync is a stub (no backend/OAuth), but this adapter
/// performs REAL local export of on-device data so users always have a
/// working, honest action.
///
/// TODO(data): OAuth account linking + REST upload for live sync, and
/// file_picker so user-supplied files can be imported.
class DataExchangeAdapter extends StubAdapter {
  DataExchangeAdapter()
      : super('Live account sync requires backend/OAuth — not configured');

  static const String _flightPlansKey = 'flight_plans';

  /// Exports saved flight plans to a portable, human-readable text document.
  ///
  /// This reads the SAME 'flight_plans' entries persisted by
  /// FlightPlanService and produces a shareable string. Returns an honest
  /// result when nothing is available to export.
  Future<ExportResult> exportFlightPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_flightPlansKey) ?? const [];
      if (saved.isEmpty) {
        return const ExportResult(
          success: false,
          message: 'No saved flight plans found to export.',
        );
      }

      final buffer = StringBuffer()
        ..writeln('PILOTENROUTE FLIGHT PLAN EXPORT')
        ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}Z')
        ..writeln('Plans: ${saved.length}')
        ..writeln('========================================');

      var index = 0;
      for (final raw in saved) {
        index++;
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          buffer
            ..writeln()
            ..writeln('PLAN $index: ${j['name'] ?? 'Unnamed'}')
            ..writeln('Rules: ${j['flightRules'] ?? 'VFR'}')
            ..writeln(
                'Aircraft: ${j['aircraftType'] ?? '-'} / ${j['tailNumber'] ?? '-'}')
            ..writeln('Departure: ${j['departure'] ?? '-'}')
            ..writeln('Destination: ${j['destination'] ?? '-'}')
            ..writeln('Alternate: ${j['alternate'] ?? 'NONE'}')
            ..writeln('Cruise Alt: ${j['cruiseAltitude'] ?? '-'} ft MSL')
            ..writeln('Cruise Speed: ${j['cruiseSpeed'] ?? '-'} kts');
          final route = j['route'];
          final waypoints = (j['waypoints'] as List<dynamic>? ?? const [])
              .map((w) => (w is Map && w['identifier'] != null)
                  ? w['identifier'].toString()
                  : '')
              .where((s) => s.isNotEmpty)
              .join(' ');
          buffer.writeln(
              'Route: ${route ?? (waypoints.isEmpty ? '-' : waypoints)}');
          if ((j['remarks'] ?? '').toString().isNotEmpty) {
            buffer.writeln('Remarks: ${j['remarks']}');
          }
        } catch (_) {
          buffer
            ..writeln()
            ..writeln('PLAN $index: <unreadable entry, skipped>');
        }
      }

      return ExportResult(
        success: true,
        message: 'Exported ${saved.length} flight plan(s).',
        content: buffer.toString(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  /// Exports saved flight plans as a GPX-like route document.
  ///
  /// Waypoints are emitted as <rtept> entries. This is intentionally a
  /// lightweight, self-contained representation (no external XML dependency)
  /// suitable for sharing / manual import into other tools.
  Future<ExportResult> exportGpxRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_flightPlansKey) ?? const [];
      if (saved.isEmpty) {
        return const ExportResult(
          success: false,
          message: 'No saved flight plans found to export.',
        );
      }

      final buffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
        ..writeln(
            '<gpx version="1.1" creator="PilotEnRoute" xmlns="http://www.topografix.com/GPX/1/1">');

      var routeCount = 0;
      for (final raw in saved) {
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          final waypoints = j['waypoints'] as List<dynamic>? ?? const [];
          if (waypoints.isEmpty) continue;
          routeCount++;
          final name = _escapeXml((j['name'] ?? 'Route').toString());
          buffer
            ..writeln('  <rte>')
            ..writeln('    <name>$name</name>');
          for (final w in waypoints) {
            if (w is! Map) continue;
            final lat = (w['lat'] ?? 0).toString();
            final lon = (w['lon'] ?? 0).toString();
            final ident = _escapeXml((w['identifier'] ?? '').toString());
            buffer
              ..writeln('    <rtept lat="$lat" lon="$lon">')
              ..writeln('      <name>$ident</name>')
              ..writeln('    </rtept>');
          }
          buffer.writeln('  </rte>');
        } catch (_) {
          // Skip unreadable entries silently.
        }
      }

      buffer.writeln('</gpx>');

      if (routeCount == 0) {
        return const ExportResult(
          success: false,
          message: 'Saved plans have no waypoints to export as GPX.',
        );
      }

      return ExportResult(
        success: true,
        message: 'Exported $routeCount route(s) to GPX.',
        content: buffer.toString(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Central hub coordinating all integration adapters and their descriptors.
///
/// Owns the adapters, exposes read-only [Integration] descriptors for the UI,
/// persists user "paired" preferences, and (honestly) reflects real
/// connection state derived from the adapters.
class IntegrationsService extends ChangeNotifier {
  static const String _pairedKey = 'integrations_paired';

  final Map<String, IntegrationAdapter> _adapters = {};
  final Map<String, Integration> _integrations = {};

  /// Ids the user has marked as "paired" / preferred (persisted).
  final Set<String> _paired = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  IntegrationsService() {
    _register();
  }

  /// Exposes the real ADS-B/simulator adapters for callers that want the
  /// (currently null) telemetry stream.
  IntegrationAdapter? adapterFor(String id) => _adapters[id];

  DataExchangeAdapter? get dataAdapter {
    for (final a in _adapters.values) {
      if (a is DataExchangeAdapter) return a;
    }
    return null;
  }

  List<Integration> get all => _integrations.values.toList();

  bool isPaired(String id) => _paired.contains(id);

  List<Integration> byCategory(IntegrationCategory category) =>
      _integrations.values.where((i) => i.category == category).toList();

  void _register() {
    void add(Integration descriptor, IntegrationAdapter adapter) {
      _integrations[descriptor.id] = descriptor;
      _adapters[descriptor.id] = adapter;
    }

    // ---- ADS-B receivers ----
    add(
      const Integration(
        id: 'adsb_stratus',
        name: 'Stratus ADS-B',
        category: IntegrationCategory.adsbReceiver,
        vendor: 'Appareo',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a Stratus receiver on its Wi-Fi network. The app must '
            'join the receiver hotspot and decode GDL90 traffic/weather over a '
            'UDP socket. Not wired yet.',
        vendorUrl: 'https://www.appareo.com/aviation/stratus/',
      ),
      AdsbReceiverAdapter(),
    );
    add(
      const Integration(
        id: 'adsb_sentry',
        name: 'Sentry ADS-B',
        category: IntegrationCategory.adsbReceiver,
        vendor: 'ForeFlight / uAvionix',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a Sentry receiver. The app must connect to the device '
            'Wi-Fi and parse GDL90 frames. Not wired yet.',
        vendorUrl: 'https://foreflight.com/products/sentry/',
      ),
      AdsbReceiverAdapter(),
    );
    add(
      const Integration(
        id: 'adsb_garmin_gdl',
        name: 'Garmin GDL 50/52',
        category: IntegrationCategory.adsbReceiver,
        vendor: 'Garmin',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a Garmin GDL portable receiver broadcasting GDL90 over '
            'Wi-Fi. Not wired yet.',
        vendorUrl: 'https://www.garmin.com/en-US/c/aviation/portable-ads-b/',
      ),
      AdsbReceiverAdapter(),
    );

    // ---- Avionics ----
    add(
      const Integration(
        id: 'avionics_garmin',
        name: 'Garmin Connext',
        category: IntegrationCategory.avionics,
        vendor: 'Garmin',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires Garmin Connext-capable avionics and the Garmin Connext '
            'SDK to exchange flight plans, GPS and traffic wirelessly. Not '
            'wired yet.',
        vendorUrl: 'https://www.garmin.com/en-US/c/aviation/',
      ),
      AvionicsAdapter(),
    );
    add(
      const Integration(
        id: 'avionics_dynon',
        name: 'Dynon SkyView',
        category: IntegrationCategory.avionics,
        vendor: 'Dynon Avionics',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a Dynon SkyView system with its Wi-Fi module and the '
            'SkyView data protocol. Not wired yet.',
        vendorUrl: 'https://dynonavionics.com/',
      ),
      AvionicsAdapter(),
    );
    add(
      const Integration(
        id: 'avionics_avidyne',
        name: 'Avidyne IFD',
        category: IntegrationCategory.avionics,
        vendor: 'Avidyne',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires an Avidyne IFD series navigator and IFD Connect SDK '
            'access. Not wired yet.',
        vendorUrl: 'https://www.avidyne.com/',
      ),
      AvionicsAdapter(),
    );

    // ---- Simulators ----
    add(
      const Integration(
        id: 'sim_xplane',
        name: 'X-Plane',
        category: IntegrationCategory.simulator,
        vendor: 'Laminar Research',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Enable Data Output in X-Plane (network, UDP) targeting this '
            'device, then ingest the GPS/position stream. Not wired yet.',
        vendorUrl: 'https://www.x-plane.com/',
      ),
      SimulatorAdapter(),
    );
    add(
      const Integration(
        id: 'sim_msfs',
        name: 'Microsoft Flight Simulator',
        category: IntegrationCategory.simulator,
        vendor: 'Microsoft / Asobo',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a SimConnect bridge that republishes MSFS position as a '
            'UDP/GPS stream to this device. Not wired yet.',
        vendorUrl: 'https://www.flightsimulator.com/',
      ),
      SimulatorAdapter(),
    );
    add(
      const Integration(
        id: 'sim_infinite_flight',
        name: 'Infinite Flight',
        category: IntegrationCategory.simulator,
        vendor: 'Infinite Flight LLC',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires the Infinite Flight Connect API over the local network. '
            'Not wired yet.',
        vendorUrl: 'https://infiniteflight.com/',
      ),
      SimulatorAdapter(),
    );
    add(
      const Integration(
        id: 'sim_p3d',
        name: 'Prepar3D',
        category: IntegrationCategory.simulator,
        vendor: 'Lockheed Martin',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a SimConnect bridge exporting Prepar3D position as a '
            'UDP/GPS stream. Not wired yet.',
        vendorUrl: 'https://www.prepar3d.com/',
      ),
      SimulatorAdapter(),
    );

    // ---- Wearables ----
    add(
      const Integration(
        id: 'wear_apple_watch',
        name: 'Apple Watch',
        category: IntegrationCategory.wearable,
        vendor: 'Apple',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a watchOS companion app using WatchConnectivity to '
            'bridge glances/session data. Not wired yet.',
        vendorUrl: 'https://www.apple.com/watch/',
      ),
      WearableAdapter(),
    );
    add(
      const Integration(
        id: 'wear_garmin',
        name: 'Garmin Wearables',
        category: IntegrationCategory.wearable,
        vendor: 'Garmin',
        connected: false,
        statusText: 'Not configured',
        requirement:
            'Requires a Garmin Connect IQ companion app to relay data from the '
            'watch. Not wired yet.',
        vendorUrl: 'https://www.garmin.com/en-US/c/wearables-smartwatches/',
      ),
      WearableAdapter(),
    );

    // ---- Data import/export ----
    add(
      const Integration(
        id: 'data_foreflight',
        name: 'ForeFlight',
        category: IntegrationCategory.dataImportExport,
        vendor: 'ForeFlight',
        connected: false,
        statusText: 'Export available',
        requirement:
            'Live account sync requires ForeFlight account linking (OAuth) and '
            'a backend. You can export your saved flight plans locally today; '
            'importing files from the device is not supported yet.',
        vendorUrl: 'https://foreflight.com/',
      ),
      DataExchangeAdapter(),
    );
    add(
      const Integration(
        id: 'data_cloudahoy',
        name: 'CloudAhoy',
        category: IntegrationCategory.dataImportExport,
        vendor: 'CloudAhoy',
        connected: false,
        statusText: 'Export available',
        requirement:
            'Live upload requires CloudAhoy account linking and their upload '
            'API. Local GPX export of your routes is available today.',
        vendorUrl: 'https://www.cloudahoy.com/',
      ),
      DataExchangeAdapter(),
    );
    add(
      const Integration(
        id: 'data_flysto',
        name: 'FlySto',
        category: IntegrationCategory.dataImportExport,
        vendor: 'FlySto',
        connected: false,
        statusText: 'Export available',
        requirement:
            'Live upload requires FlySto account linking and their API. Local '
            'export of your saved flight plans is available today.',
        vendorUrl: 'https://www.flysto.net/',
      ),
      DataExchangeAdapter(),
    );
  }

  /// Loads persisted "paired" preferences. Safe to call multiple times.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_pairedKey) ?? const [];
      _paired
        ..clear()
        ..addAll(saved);
    } catch (_) {
      // Non-fatal: start with no paired preferences.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Records/clears a user "paired" preference for an integration and persists.
  Future<void> setPaired(String id, bool paired) async {
    if (paired) {
      _paired.add(id);
    } else {
      _paired.remove(id);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pairedKey, _paired.toList());
    } catch (_) {
      // Non-fatal: the in-memory state still reflects the change.
    }
    notifyListeners();
  }

  /// Attempts a real connection through the adapter and syncs the descriptor
  /// from the adapter's honest state. Returns whether a connection was made.
  Future<bool> connect(String id) async {
    final adapter = _adapters[id];
    final descriptor = _integrations[id];
    if (adapter == null || descriptor == null) return false;

    var ok = false;
    try {
      ok = await adapter.connect();
    } catch (_) {
      ok = false;
    }

    _integrations[id] = descriptor.copyWith(
      connected: adapter.isConnected,
      statusText: adapter.isConnected ? adapter.statusText : descriptor.statusText,
    );
    notifyListeners();
    return ok;
  }

  Future<void> disconnect(String id) async {
    final adapter = _adapters[id];
    final descriptor = _integrations[id];
    if (adapter == null || descriptor == null) return;
    try {
      await adapter.disconnect();
    } catch (_) {
      // Ignore teardown errors.
    }
    _integrations[id] = descriptor.copyWith(
      connected: adapter.isConnected,
    );
    notifyListeners();
  }
}
