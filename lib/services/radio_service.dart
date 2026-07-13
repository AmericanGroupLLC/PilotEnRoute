import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single free ATC audio feed sourced from LiveATC.net.
///
/// [streamUrl] uses the LiveATC direct-stream form `https://d.liveatc.net/<feed>`.
class AtcFeed {
  final String id;
  final String airport;
  final String name;
  final String streamUrl;

  const AtcFeed({
    required this.id,
    required this.airport,
    required this.name,
    required this.streamUrl,
  });
}

/// Wraps an [AudioPlayer] to stream live ATC audio one feed at a time.
///
/// This is a plain [ChangeNotifier] — own it in a [State] and dispose it there;
/// no provider is required.
class RadioService extends ChangeNotifier {
  RadioService() {
    _stateSub = _player.onPlayerStateChanged.listen(_onStateChanged);
    _loadLastFeed();
  }

  // TODO(atc): LiveATC feed ids/availability change; some feeds are offline at
  // times. For production use an official/licensed ATC audio provider or the
  // LiveATC feed directory.
  static const List<AtcFeed> feeds = [
    AtcFeed(
      id: 'kjfk_twr',
      airport: 'KJFK',
      name: 'New York (JFK) Tower',
      streamUrl: 'https://d.liveatc.net/kjfk_twr',
    ),
    AtcFeed(
      id: 'klax_twr',
      airport: 'KLAX',
      name: 'Los Angeles (LAX) Tower',
      streamUrl: 'https://d.liveatc.net/klax_twr',
    ),
    AtcFeed(
      id: 'kbos_twr',
      airport: 'KBOS',
      name: 'Boston (BOS) Tower',
      streamUrl: 'https://d.liveatc.net/kbos_twr',
    ),
    AtcFeed(
      id: 'katl_twr',
      airport: 'KATL',
      name: 'Atlanta (ATL) Tower',
      streamUrl: 'https://d.liveatc.net/katl_twr',
    ),
    AtcFeed(
      id: 'ksfo_twr',
      airport: 'KSFO',
      name: 'San Francisco (SFO) Tower',
      streamUrl: 'https://d.liveatc.net/ksfo_twr',
    ),
    AtcFeed(
      id: 'kord_twr',
      airport: 'KORD',
      name: 'Chicago (ORD) Tower',
      streamUrl: 'https://d.liveatc.net/kord_twr',
    ),
  ];

  static const String _prefsKey = 'radio_last_feed_id';

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;

  String? _currentFeedId;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _lastFeedId;

  /// Id of the feed currently loaded/playing (null when stopped).
  String? get currentFeedId => _currentFeedId;

  /// Id of the most recently played feed (persisted across sessions).
  String? get lastFeedId => _lastFeedId;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;

  AtcFeed? get currentFeed {
    if (_currentFeedId == null) return null;
    for (final f in feeds) {
      if (f.id == _currentFeedId) return f;
    }
    return null;
  }

  bool isFeedPlaying(String feedId) =>
      _currentFeedId == feedId && (_isPlaying || _isBuffering);

  Future<void> _loadLastFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastFeedId = prefs.getString(_prefsKey);
      notifyListeners();
    } catch (_) {
      // Non-fatal: persistence is a convenience only.
    }
  }

  Future<void> _saveLastFeed(String feedId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, feedId);
    } catch (_) {
      // Non-fatal.
    }
  }

  void _onStateChanged(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        _isPlaying = true;
        _isBuffering = false;
        break;
      case PlayerState.paused:
        _isPlaying = false;
        _isBuffering = false;
        break;
      case PlayerState.stopped:
      case PlayerState.completed:
        _isPlaying = false;
        _isBuffering = false;
        _currentFeedId = null;
        break;
      case PlayerState.disposed:
        _isPlaying = false;
        _isBuffering = false;
        break;
    }
    notifyListeners();
  }

  /// Starts (or restarts) streaming [feed]. Only one feed plays at a time.
  ///
  /// Throws if the stream cannot be started so callers can surface an error;
  /// state is always left consistent.
  Future<void> play(AtcFeed feed) async {
    try {
      // Tear down any active stream first (single-feed playback).
      await _player.stop();

      _currentFeedId = feed.id;
      _isBuffering = true;
      _isPlaying = false;
      _lastFeedId = feed.id;
      notifyListeners();

      await _saveLastFeed(feed.id);
      await _player.play(UrlSource(feed.streamUrl));
    } catch (e) {
      _isBuffering = false;
      _isPlaying = false;
      _currentFeedId = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore — we still reset local state below.
    }
    _isPlaying = false;
    _isBuffering = false;
    _currentFeedId = null;
    notifyListeners();
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {
      // Ignore.
    }
    _isPlaying = false;
    _isBuffering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
