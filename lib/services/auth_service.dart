import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/backend_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — REAL client against the AmericanGroupLLC backend.
//
// Supports Email/Password, backend-brokered social login (Google/Apple/
// Facebook via OAuth start URL + WebView), and Firebase Phone OTP verification.
//
// Endpoints and client-public config live in BackendConfig. This service never
// throws to the UI: every operation returns an AuthResult or a safe fallback.
//
// TODO(secure-storage): move JWTs to flutter_secure_storage / Keychain /
// Keystore per the integration guide. shared_preferences is used for now
// because flutter_secure_storage is not a dependency in this project.
// ─────────────────────────────────────────────────────────────────────────────

/// Account roles supported by the app.
enum UserRole { student, cfi, operator, admin }

extension UserRoleX on UserRole {
  /// Stable string used for persistence / API values (never localize this).
  String get id => name;

  /// Human-friendly label for display.
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.cfi:
        return 'CFI';
      case UserRole.operator:
        return 'Operator';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromId(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    return UserRole.values.firstWhere(
      (r) => r.id == normalized,
      orElse: () => UserRole.student,
    );
  }
}

/// Immutable snapshot of the signed-in user. JSON parsing is defensive: the
/// backend may return `id` or `user_id`, `name` or `full_name`, etc.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String? name;
  final UserRole role;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.id,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    return AuthUser(
      id: pick(['id', 'user_id', 'uid', 'sub']) ?? '',
      email: pick(['email', 'email_address']) ?? '',
      name: pick(['name', 'full_name', 'display_name', 'username']),
      role: UserRoleX.fromId(pick(['role', 'user_role', 'type'])),
    );
  }
}

/// Result of any auth operation. Never throws to the UI layer.
class AuthResult {
  const AuthResult(this.ok, {this.error, this.user});

  const AuthResult.success(AuthUser this.user)
      : ok = true,
        error = null;

  const AuthResult.failure(String this.error)
      : ok = false,
        user = null;

  final bool ok;
  final String? error;
  final AuthUser? user;
}

class AuthService extends ChangeNotifier {
  AuthService._internal();

  /// The one and only instance.
  static final AuthService instance = AuthService._internal();

  /// So existing `AuthService()` call sites resolve to the singleton.
  factory AuthService() => instance;

  // ── Persistence keys ────────────────────────────────────────────────────────
  static const String _kAccessTokenKey = 'agl_access_token';
  static const String _kRefreshTokenKey = 'agl_refresh_token';
  static const String _kUserIdKey = 'agl_user_id';

  /// Validation rule (referenced by the UI).
  static const int minPasswordLength = 6;

  /// Network timeout for all requests.
  static const Duration _timeout = Duration(seconds: 15);

  // ── State ────────────────────────────────────────────────────────────────────
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  AuthUser? _currentUser;
  bool _initialized = false;
  bool _isBusy = false;

  // ── Public getters (contract) ───────────────────────────────────────────────
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;
  bool get isBusy => _isBusy;
  bool get isInitialized => _initialized;

  /// Test Firebase ID token for SIM-less phone-auth testing.
  static String get phoneTestToken => BackendConfig.phoneTestFirebaseToken;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Load persisted session from prefs, then best-effort refresh the profile.
  /// Safe to call multiple times.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccessTokenKey);
      _refreshToken = prefs.getString(_kRefreshTokenKey);
      _userId = prefs.getString(_kUserIdKey);
    } catch (_) {
      // Corrupt/unavailable prefs — treat as signed out, never crash.
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
    }
    _initialized = true;
    notifyListeners();

    if (_accessToken != null) {
      // Best-effort: populate the profile. Ignores failures.
      try {
        await fetchMe();
      } catch (_) {
        // Keep the session; UI can still function offline.
      }
    }
  }

  // ── Email / password ──────────────────────────────────────────────────────────

  Future<AuthResult> registerEmail(
    String email,
    String password, {
    String? name,
  }) async {
    final normalizedEmail = email.trim();
    final body = <String, dynamic>{
      'email': normalizedEmail,
      'password': password,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
      body['full_name'] = name.trim();
    }
    return _authWithTokens(BackendConfig.registerPath, body);
  }

  Future<AuthResult> loginEmail(String email, String password) async {
    return _authWithTokens(BackendConfig.loginPath, {
      'email': email.trim(),
      'password': password,
    });
  }

  // ── Social login ──────────────────────────────────────────────────────────────

  /// Backend OAuth start URL for `provider` ('google'|'apple'|'facebook'...).
  String socialStartUrl(String provider) =>
      BackendConfig.socialStartUrl(provider);

  /// Completes a social login after the WebView returns tokens. Stores them and
  /// fetches the profile.
  Future<AuthResult> completeSocialLogin({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      return const AuthResult.failure('Social login did not return a token.');
    }
    _setBusy(true);
    try {
      await _storeTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: _userId,
      );
      final user = await fetchMe();
      if (user != null) return AuthResult.success(user);
      // Tokens are valid enough to be stored; profile fetch is best-effort.
      return const AuthResult(true);
    } catch (_) {
      return const AuthResult.failure('Could not complete social login.');
    } finally {
      _setBusy(false);
    }
  }

  // ── Phone OTP (Firebase) ──────────────────────────────────────────────────────

  /// Verifies a Firebase phone ID token with the backend and stores the
  /// returned JWTs.
  ///
  /// TODO(firebase): integrate firebase_auth signInWithPhoneNumber to obtain a
  /// real id_token; google-services.json / GoogleService-Info.plist required
  /// (Firebase project americangroupllc-5bdfc).
  Future<AuthResult> verifyFirebasePhone(String firebaseIdToken) async {
    if (firebaseIdToken.trim().isEmpty) {
      return const AuthResult.failure('Missing Firebase ID token.');
    }
    return _authWithTokens(BackendConfig.firebaseVerifyPath, {
      'id_token': firebaseIdToken,
    });
  }

  // ── Token / session ───────────────────────────────────────────────────────────

  /// Refresh the access token using the stored refresh token. Returns true on
  /// success.
  Future<bool> refresh() async {
    final rt = _refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final resp = await http
          .post(
            _uri(BackendConfig.refreshPath),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': rt}),
          )
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      final map = _decode(resp.body);
      if (map == null) return false;
      final newAccess = _str(map, ['access_token']);
      if (newAccess == null || newAccess.isEmpty) return false;
      await _storeTokens(
        accessToken: newAccess,
        refreshToken: _str(map, ['refresh_token']) ?? rt,
        userId: _str(map, ['user_id']) ?? _userId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /auth/me with Bearer. On 401, attempts one refresh then retries.
  Future<AuthUser?> fetchMe() async {
    final user = await _fetchMeOnce();
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
    return user;
  }

  Future<AuthUser?> _fetchMeOnce({bool allowRefresh = true}) async {
    final token = _accessToken;
    if (token == null) return null;
    try {
      final resp = await http
          .get(_uri(BackendConfig.mePath), headers: _authHeaders(token))
          .timeout(_timeout);
      if (resp.statusCode == 401 && allowRefresh) {
        if (await refresh()) {
          return _fetchMeOnce(allowRefresh: false);
        }
        return null;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final map = _decode(resp.body);
      if (map == null) return null;
      // Some backends wrap the user under 'user' / 'data'.
      final inner = map['user'] ?? map['data'];
      final userMap = inner is Map<String, dynamic> ? inner : map;
      return AuthUser.fromJson(userMap);
    } catch (_) {
      return null;
    }
  }

  /// Sign out: best-effort backend logout, then clear all local state.
  Future<void> signOut() async {
    final token = _accessToken;
    if (token != null) {
      try {
        await http
            .post(
              _uri(BackendConfig.logoutPath),
              headers: _authHeaders(token),
              body: jsonEncode({
                if (_refreshToken != null) 'refresh_token': _refreshToken,
              }),
            )
            .timeout(_timeout);
      } catch (_) {
        // Ignore — clearing local state below is what matters.
      }
    }
    await _clearTokens();
  }

  // ── Validation helpers (exposed for the UI to reuse) ───────────────────────────

  /// Returns an error string, or null if valid.
  String? validateEmailField(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Please enter your email.';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  /// Returns an error string, or null if valid.
  String? validatePasswordField(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }

  // ── Internal request helpers ───────────────────────────────────────────────────

  /// Shared flow for register / login / firebase-verify: POST [path] with
  /// [body], expect {access_token, refresh_token, user_id}, store them, then
  /// fetch the profile.
  Future<AuthResult> _authWithTokens(
    String path,
    Map<String, dynamic> body,
  ) async {
    _setBusy(true);
    try {
      final resp = await http
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final map = _decode(resp.body);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return AuthResult.failure(_errorFrom(map, resp.statusCode));
      }
      if (map == null) {
        return const AuthResult.failure('Unexpected response from server.');
      }

      final access = _str(map, ['access_token']);
      final refreshTok = _str(map, ['refresh_token']);
      if (access == null || access.isEmpty) {
        return AuthResult.failure(_errorFrom(map, resp.statusCode));
      }

      await _storeTokens(
        accessToken: access,
        refreshToken: refreshTok,
        userId: _str(map, ['user_id']),
      );

      // Prefer a fresh profile; fall back to any inline user object.
      final user = await fetchMe() ?? _inlineUser(map);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return AuthResult.success(user);
      }
      return const AuthResult(true);
    } on TimeoutException {
      return const AuthResult.failure(
        'The request timed out. Please try again.',
      );
    } catch (_) {
      return const AuthResult.failure(
        'Network error. Check your connection and try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  AuthUser? _inlineUser(Map<String, dynamic> map) {
    final inner = map['user'] ?? map['data'];
    if (inner is Map<String, dynamic>) return AuthUser.fromJson(inner);
    if (_userId != null && _userId!.isNotEmpty) {
      return AuthUser(id: _userId!, email: '', name: null, role: UserRole.student);
    }
    return null;
  }

  Uri _uri(String path) => Uri.parse('${BackendConfig.apiBaseUrl}$path');

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Non-JSON body.
    }
    return null;
  }

  String? _str(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null) {
        final s = v.toString();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  /// Extract the standard {"error":"..."} envelope, with sensible fallbacks.
  String _errorFrom(Map<String, dynamic>? map, int status) {
    if (map != null) {
      final err = _str(map, ['error', 'message', 'detail', 'error_description']);
      if (err != null && err.isNotEmpty) return err;
    }
    if (status == 401 || status == 403) {
      return 'Invalid credentials.';
    }
    return 'Request failed (HTTP $status).';
  }

  // ── Token storage ──────────────────────────────────────────────────────────────
  //
  // TODO(secure-storage): move JWTs to flutter_secure_storage / Keychain /
  // Keystore per the integration guide.

  Future<void> _storeTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    if (userId != null && userId.isNotEmpty) {
      _userId = userId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessTokenKey, _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString(_kRefreshTokenKey, _refreshToken!);
      }
      if (_userId != null) {
        await prefs.setString(_kUserIdKey, _userId!);
      }
    } catch (_) {
      // In-memory tokens still work for this session.
    }
    notifyListeners();
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessTokenKey);
      await prefs.remove(_kRefreshTokenKey);
      await prefs.remove(_kUserIdKey);
    } catch (_) {
      // Ignore — in-memory state is already cleared.
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }
}
