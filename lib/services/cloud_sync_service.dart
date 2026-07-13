import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CloudSyncService — backup/restore of key app data behind a swappable client.
//
// This ships a LOCAL stub (LocalSnapshotBackendClient) that snapshots app data
// into a single 'cloud_snapshot' pref, simulating backup/restore across the
// SAME device only. It does NOT provide multi-device sync and never claims to.
//
// TODO(sync): point BackendClient at a real API for true multi-device sync.
// ─────────────────────────────────────────────────────────────────────────────

/// High-level sync state for the UI.
enum SyncStatus { idle, syncing, error, offline }

/// Clean seam for the backend. Drop in a real implementation (REST, Firestore,
/// etc.) and the service + UI stay unchanged.
///
/// A "snapshot" is an opaque JSON-encodable map owned by the service.
abstract class BackendClient {
  /// Whether a remote destination is reachable/configured.
  Future<bool> isAvailable();

  /// Push a snapshot to the backend. Should throw on failure.
  Future<void> upload(Map<String, dynamic> snapshot);

  /// Pull the latest snapshot, or null if none exists.
  Future<Map<String, dynamic>?> download();
}

/// Default backend: stores a single snapshot in shared_preferences.
///
/// This is intentionally same-device only. It is NOT a real cloud backend.
/// TODO(sync): replace with a networked BackendClient for multi-device sync.
class LocalSnapshotBackendClient implements BackendClient {
  static const String _kSnapshotKey = 'cloud_snapshot';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> upload(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSnapshotKey, jsonEncode(snapshot));
  }

  @override
  Future<Map<String, dynamic>?> download() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }
}

class CloudSyncService extends ChangeNotifier {
  CloudSyncService({BackendClient? client})
      : _client = client ?? LocalSnapshotBackendClient();

  final BackendClient _client;

  // Persistence key for the last-synced timestamp.
  static const String _kLastSyncedKey = 'cloud_last_synced_at';

  // App-data pref keys captured in a snapshot.
  //
  // NOTE: the logbook is stored in a local database (sqlite/Hive), NOT in
  // shared_preferences, so it is intentionally NOT captured by this stub. A
  // real BackendClient should export the logbook DB separately.
  // TODO(sync): include logbook DB export once a real backend is available.
  static const List<String> _syncedPrefKeys = <String>[
    'flight_plans', // flight plans (List<String> of JSON)
    'profile_name',
    'profile_cert',
    'profile_level',
    'profile_medical',
    'profile_medical_expiry',
    'profile_bfr_expiry',
    'documents_metadata', // documents/endorsements metadata, if present
  ];

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  String? _lastError;
  bool _initialized = false;

  SyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get isInitialized => _initialized;
  bool get isBusy => _status == SyncStatus.syncing;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getString(_kLastSyncedKey);
      if (ts != null && ts.isNotEmpty) {
        _lastSyncedAt = DateTime.tryParse(ts);
      }
    } catch (_) {
      _lastSyncedAt = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Backup: snapshot local app data and hand it to the backend client.
  Future<void> syncUp() async {
    if (_status == SyncStatus.syncing) return;
    _setStatus(SyncStatus.syncing);
    try {
      if (!await _client.isAvailable()) {
        _lastError = 'Backend not available.';
        _setStatus(SyncStatus.offline);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final snapshot = _buildSnapshot(prefs);
      await _client.upload(snapshot);
      await _stampLastSynced(prefs);
      _lastError = null;
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _lastError = 'Backup failed: $e';
      _setStatus(SyncStatus.error);
    }
  }

  /// Restore: pull the latest snapshot and write it back into local prefs.
  Future<void> syncDown() async {
    if (_status == SyncStatus.syncing) return;
    _setStatus(SyncStatus.syncing);
    try {
      if (!await _client.isAvailable()) {
        _lastError = 'Backend not available.';
        _setStatus(SyncStatus.offline);
        return;
      }
      final snapshot = await _client.download();
      if (snapshot == null) {
        _lastError = 'No backup found to restore.';
        _setStatus(SyncStatus.error);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await _applySnapshot(prefs, snapshot);
      await _stampLastSynced(prefs);
      _lastError = null;
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _lastError = 'Restore failed: $e';
      _setStatus(SyncStatus.error);
    }
  }

  // ── Snapshot helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _buildSnapshot(SharedPreferences prefs) {
    final data = <String, dynamic>{};
    for (final key in _syncedPrefKeys) {
      final value = prefs.get(key);
      if (value == null) continue;
      if (value is List) {
        // Preserve List<String> (e.g. flight_plans) with a type tag.
        data[key] = {'_type': 'stringList', 'value': value};
      } else {
        data[key] = {'_type': 'string', 'value': value.toString()};
      }
    }
    return {
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      // NOTE: same-device local snapshot only. Not synced to any server.
      'source': 'local_stub',
      'data': data,
    };
  }

  Future<void> _applySnapshot(
    SharedPreferences prefs,
    Map<String, dynamic> snapshot,
  ) async {
    final data = snapshot['data'];
    if (data is! Map<String, dynamic>) return;
    for (final entry in data.entries) {
      if (!_syncedPrefKeys.contains(entry.key)) continue;
      final wrapped = entry.value;
      if (wrapped is! Map<String, dynamic>) continue;
      final type = wrapped['_type'];
      final value = wrapped['value'];
      if (type == 'stringList' && value is List) {
        await prefs.setStringList(
          entry.key,
          value.map((e) => e.toString()).toList(),
        );
      } else if (type == 'string' && value != null) {
        await prefs.setString(entry.key, value.toString());
      }
    }
  }

  Future<void> _stampLastSynced(SharedPreferences prefs) async {
    _lastSyncedAt = DateTime.now();
    await prefs.setString(_kLastSyncedKey, _lastSyncedAt!.toIso8601String());
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }
}
