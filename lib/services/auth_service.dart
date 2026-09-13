import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// Narrow `show` list keeps Supabase's exports (which include a `Provider`
// symbol) from clashing with other packages elsewhere in the app.
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        AuthException,
        AuthResponse,
        AuthRetryableFetchException,
        AuthState,
        AuthChangeEvent,
        OAuthProvider,
        User;

import '../config/backend_config.dart';
import 'supabase_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — REAL client against the org's Supabase backend.
//
// Email/password sign-in goes through Supabase Auth
// (`Supabase.instance.client.auth.signInWithPassword`). Supabase persists and
// auto-restores its own session, so a networked device always uses the real
// backend.
//
// Backend-brokered social login (Google/Apple/Facebook via OAuth start URL +
// WebView) and Firebase Phone OTP verification still go through the
// AmericanGroupLLC API gateway (see BackendConfig) and are unchanged.
//
// Offline fallback: when the device cannot reach Supabase (network/socket
// error) AND the entered credentials match a shared SupabaseConfig QA/Dev test
// account, we fall back to a persisted local demo session so the app stays
// testable without connectivity. A genuine Supabase AuthException (bad
// credentials, etc.) NEVER falls back. See [loginEmail].
//
// This service never throws to the UI: every operation returns an AuthResult
// or a safe fallback.
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
  const AuthResult(this.ok, {this.error, this.user, this.cancelled = false});

  const AuthResult.success(AuthUser this.user)
    : ok = true,
      error = null,
      cancelled = false;

  const AuthResult.failure(String this.error)
    : ok = false,
      user = null,
      cancelled = false;

  /// The user backed out of a native sign-in sheet (Apple / Google). Not an
  /// error — the UI stays silent rather than showing a failure message.
  const AuthResult.cancelled()
    : ok = false,
      error = null,
      user = null,
      cancelled = true;

  final bool ok;
  final String? error;
  final AuthUser? user;
  final bool cancelled;
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
  static const String _kIsLocalKey = 'agl_is_local_session';
  static const String _kLocalEmailKey = 'agl_local_email';
  static const String _kLocalNameKey = 'agl_local_name';

  // ── Local demo (offline fallback) identifiers ────────────────────────────────
  static const String _kLocalDemoToken = 'local-demo-token';
  static const String _kLocalDemoUserId = 'local-demo-user';

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
  bool _isLocal = false;
  bool _guest = false;
  bool _supabaseSession = false;

  /// Live subscription to Supabase auth-state changes (sign-in / token-refresh /
  /// sign-out). Kept so a background token refresh or an out-of-band session
  /// change keeps the app's auth state — and the AuthGate — in sync.
  StreamSubscription<AuthState>? _authSub;

  // ── Public getters (contract) ───────────────────────────────────────────────
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;
  bool get isBusy => _isBusy;
  bool get isInitialized => _initialized;

  /// True when signed in with the built-in offline test account.
  bool get isLocalSession => _isLocal;

  /// True when the user chose to browse without signing in.
  bool get isGuest => _guest;

  /// The gate should show the main app when authenticated OR browsing as guest.
  bool get canEnterApp => isAuthenticated || _guest;

  /// Test Firebase ID token for SIM-less phone-auth testing.
  static String get phoneTestToken => BackendConfig.phoneTestFirebaseToken;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Restore any persisted session, then best-effort refresh the profile.
  /// Safe to call multiple times.
  ///
  /// Precedence: a live Supabase session (auto-restored by the SDK on a
  /// networked device) wins; otherwise a persisted local demo session; otherwise
  /// a legacy BackendConfig token session (social / phone).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLocal = prefs.getBool(_kIsLocalKey) ?? false;
      if (_isLocal) {
        // Offline demo session persisted by the network fallback.
        _accessToken = _kLocalDemoToken;
        _userId = prefs.getString(_kUserIdKey);
        _currentUser = AuthUser(
          id: _userId ?? _kLocalDemoUserId,
          // qaEmail is empty in a shipped build, so fall back to a neutral
          // placeholder rather than rendering an empty address.
          email:
              prefs.getString(_kLocalEmailKey) ??
              (SupabaseConfig.qaEmail.isNotEmpty
                  ? SupabaseConfig.qaEmail
                  : 'demo@local'),
          name: prefs.getString(_kLocalNameKey) ?? 'Test Pilot',
          role: UserRole.student,
        );
      } else {
        // Legacy backend-token session (social / phone login).
        _accessToken = prefs.getString(_kAccessTokenKey);
        _refreshToken = prefs.getString(_kRefreshTokenKey);
        _userId = prefs.getString(_kUserIdKey);
      }
    } catch (_) {
      // Corrupt/unavailable prefs — treat as signed out, never crash.
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      _isLocal = false;
      _currentUser = null;
    }

    // Adopt a real Supabase session if the SDK auto-restored one. This takes
    // precedence over any legacy/local session above.
    _supabaseSession = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      if (session != null && user != null) {
        _supabaseSession = true;
        _isLocal = false;
        _accessToken = session.accessToken;
        _refreshToken = session.refreshToken;
        _userId = user.id;
        _currentUser = _userFromSupabase(user);
      }
    } catch (_) {
      // Supabase not initialized / unavailable — ignore and use any local state.
    }

    // AUTO-LOGIN: keep the app in sync with the persistent, auto-refreshing
    // Supabase session for its whole lifetime. We subscribe once; the SDK emits
    // signedIn on restore, tokenRefreshed in the background, and signedOut only
    // on an explicit sign-out — never on launch — so a returning user stays
    // signed in with no login screen.
    try {
      _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen(
        _onAuthState,
      );
    } catch (_) {
      // Supabase not initialized (offline) — nothing to observe.
    }

    _initialized = true;
    notifyListeners();

    // Best-effort profile fetch only for legacy backend-token sessions. The
    // local demo session has no server to hit, and a Supabase session already
    // carries its user.
    if (_accessToken != null && !_isLocal && !_supabaseSession) {
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

  /// Email/password sign-in via the org's Supabase Auth backend.
  ///
  /// A networked device always authenticates against Supabase. Only when the
  /// device cannot reach Supabase (network/socket error) AND the credentials
  /// match a shared SupabaseConfig QA/Dev test account do we fall back to a
  /// persisted local demo session. A genuine Supabase [AuthException] (bad
  /// credentials, unconfirmed email, etc.) is returned as-is and NEVER falls
  /// back.
  Future<AuthResult> loginEmail(String email, String password) async {
    final normalizedEmail = email.trim();
    _setBusy(true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final sUser = response.user;
      final sSession = response.session;
      if (sUser == null || sSession == null) {
        return const AuthResult.failure('Invalid credentials.');
      }
      // Real Supabase session — supersedes any stale local demo session.
      await _clearLocalDemoSession();
      _supabaseSession = true;
      _isLocal = false;
      _guest = false;
      _accessToken = sSession.accessToken;
      _refreshToken = sSession.refreshToken;
      _userId = sUser.id;
      final user = _userFromSupabase(sUser);
      _currentUser = user;
      notifyListeners();
      return AuthResult.success(user);
    } on AuthRetryableFetchException {
      // Retryable transport failure (couldn't reach Supabase). Treat as an
      // offline/network error — eligible for the local demo fallback.
      return _networkFallback(normalizedEmail, password);
    } on AuthException catch (e) {
      // Definitive rejection from Supabase (bad credentials, etc.). Never fall
      // back to the local demo session, even for a test account.
      return AuthResult.failure(e.message);
    } catch (_) {
      // SocketException / http ClientException / TimeoutException / any other
      // transport failure — same offline fallback rules as above.
      return _networkFallback(normalizedEmail, password);
    } finally {
      _setBusy(false);
    }
  }

  /// Convenience entry point for the one-tap "Use test account" button — signs
  /// in with the shared QA account from SupabaseConfig.
  ///
  /// Fails fast in a build with no QA credentials rather than attempting a
  /// sign-in with two empty strings.
  Future<AuthResult> signInWithTestAccount() {
    if (!SupabaseConfig.testAccountEnabled) {
      throw StateError(
        'No QA credentials in this build. Supply QA_EMAIL / QA_PASSWORD via '
        '--dart-define for an internal build.',
      );
    }
    return loginEmail(SupabaseConfig.qaEmail, SupabaseConfig.qaPassword);
  }

  /// Offline fallback path: only shared SupabaseConfig test accounts may drop to
  /// a local demo session when Supabase is unreachable; everyone else gets a
  /// normal network error.
  Future<AuthResult> _networkFallback(String email, String password) async {
    if (_isSupabaseTestAccount(email, password)) {
      return _signInLocalDemo(email);
    }
    return const AuthResult.failure(
      'Network error. Check your connection and try again.',
    );
  }

  /// True when [email]/[password] match a shared SupabaseConfig QA or Dev
  /// account (case-insensitive on the email).
  bool _isSupabaseTestAccount(String email, String password) {
    final e = email.trim().toLowerCase();
    return (SupabaseConfig.testAccountEnabled &&
            e == SupabaseConfig.qaEmail.toLowerCase() &&
            password == SupabaseConfig.qaPassword) ||
        (SupabaseConfig.devAccountEnabled &&
            e == SupabaseConfig.devEmail.toLowerCase() &&
            password == SupabaseConfig.devPassword);
  }

  /// Map a Supabase [User] onto the app's [AuthUser], reading name/role from
  /// user metadata when present.
  AuthUser _userFromSupabase(User u) {
    final meta = u.userMetadata ?? const <String, dynamic>{};
    String? metaStr(List<String> keys) {
      for (final k in keys) {
        final v = meta[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    return AuthUser(
      id: u.id,
      email: u.email ?? metaStr(['email']) ?? '',
      name: metaStr(['name', 'full_name', 'display_name']),
      role: UserRoleX.fromId(metaStr(['role', 'user_role'])),
    );
  }

  /// Reacts to Supabase auth-state changes so the app's session state (and the
  /// AuthGate) tracks background token refreshes and out-of-band changes.
  void _onAuthState(AuthState data) {
    final session = data.session;
    switch (data.event) {
      case AuthChangeEvent.signedOut:
        // Only clear if a Supabase session was the active one; never clobber a
        // local demo or guest session.
        if (_supabaseSession) {
          _supabaseSession = false;
          _accessToken = null;
          _refreshToken = null;
          _userId = null;
          _currentUser = null;
          notifyListeners();
        }
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        if (session == null) return;
        _supabaseSession = true;
        _isLocal = false;
        _guest = false;
        _accessToken = session.accessToken;
        _refreshToken = session.refreshToken;
        _userId = session.user.id;
        var mapped = _userFromSupabase(session.user);
        // Preserve a name captured elsewhere (e.g. Apple's first-authorization
        // full name) that the raw token/metadata may not carry.
        final existing = _currentUser;
        if ((mapped.name == null || mapped.name!.trim().isEmpty) &&
            existing != null &&
            existing.id == mapped.id &&
            (existing.name?.trim().isNotEmpty ?? false)) {
          mapped = AuthUser(
            id: mapped.id,
            email: mapped.email,
            name: existing.name,
            role: mapped.role,
          );
        }
        _currentUser = mapped;
        notifyListeners();
      default:
        // initialSession / passwordRecovery / mfa — no state change here.
        break;
    }
  }

  // ── Native OAuth (Supabase-native ID-token flow) ────────────────────────────

  /// Sign in with Apple via the Supabase-native ID-token flow.
  ///
  /// Generates a cryptographically random raw nonce and sends its SHA-256 hash
  /// to Apple; Apple binds the hash into the returned identity token, and
  /// Supabase re-derives the hash from the raw nonce to verify the binding
  /// (replay protection). Supabase auto-creates the account on first sign-in.
  Future<AuthResult> signInWithApple() async {
    _setBusy(true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return const AuthResult.failure(
          'Apple sign-in failed: missing identity token.',
        );
      }

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Apple returns the name only on the FIRST authorization — capture it now.
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ').trim();
      return await _adoptSupabaseSession(
        res,
        preferredName: fullName.isNotEmpty ? fullName : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.cancelled();
      }
      return const AuthResult.failure(
        'Apple sign-in failed. Please try again.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure(
        'Sign-in unavailable right now. Please try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Sign in with Google via the Supabase-native ID-token flow.
  ///
  /// The native SDK returns a Google `idToken` (+ `accessToken`); Supabase
  /// exchanges them for a session and auto-creates the account on first
  /// sign-in. [SupabaseConfig.googleServerClientId] (the web/server client id)
  /// must match the Google provider's configured Client ID in the Supabase
  /// dashboard, or the exchange is rejected.
  Future<AuthResult> signInWithGoogle() async {
    _setBusy(true);
    try {
      const iosClientId = SupabaseConfig.googleIosClientId;
      final googleSignIn = GoogleSignIn(
        serverClientId: SupabaseConfig.googleServerClientId,
        clientId: iosClientId.isNotEmpty ? iosClientId : null,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        return const AuthResult.cancelled();
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return const AuthResult.failure(
          'Google sign-in failed: missing ID token.',
        );
      }

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      return await _adoptSupabaseSession(res);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      if (_looksCancelled(e)) return const AuthResult.cancelled();
      return const AuthResult.failure(
        'Sign-in unavailable right now. Please try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Seamless, no-login identity. Creates a real (anonymous) Supabase session
  /// that persists and can later be upgraded to a full account.
  Future<AuthResult> signInAnonymously() async {
    _setBusy(true);
    try {
      final res = await Supabase.instance.client.auth.signInAnonymously();
      return await _adoptSupabaseSession(res, preferredName: 'Guest');
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure('Anonymous sign-in failed.');
    } finally {
      _setBusy(false);
    }
  }

  /// Adopts a live Supabase [res]ponse as the current session (supersedes any
  /// stale local demo session). [preferredName] supplies a display name the
  /// token itself may not carry (e.g. Apple's first-authorization full name).
  Future<AuthResult> _adoptSupabaseSession(
    AuthResponse res, {
    String? preferredName,
  }) async {
    final sUser = res.user;
    final sSession = res.session;
    if (sUser == null || sSession == null) {
      return const AuthResult.failure('Sign-in failed: no session returned.');
    }
    await _clearLocalDemoSession();
    _supabaseSession = true;
    _isLocal = false;
    _guest = false;
    _accessToken = sSession.accessToken;
    _refreshToken = sSession.refreshToken;
    _userId = sUser.id;
    var user = _userFromSupabase(sUser);
    if ((user.name == null || user.name!.trim().isEmpty) &&
        preferredName != null &&
        preferredName.trim().isNotEmpty) {
      user = AuthUser(
        id: user.id,
        email: user.email,
        name: preferredName.trim(),
        role: user.role,
      );
    }
    _currentUser = user;
    notifyListeners();
    return AuthResult.success(user);
  }

  /// Cryptographically secure random nonce (URL-safe charset) for Apple sign-in.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Heuristic: did a native SDK throw because the user backed out?
  bool _looksCancelled(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('cancel') || s.contains('canceled');
  }

  /// Enter the app without signing in (in-memory only; login shows again on a
  /// fresh launch).
  void continueAsGuest() {
    if (_guest) return;
    _guest = true;
    notifyListeners();
  }

  /// Create/restore a persisted OFFLINE demo session for a shared SupabaseConfig
  /// test account. Only reached from the network fallback in [loginEmail] when
  /// Supabase is unreachable — a networked device always uses the real backend.
  /// Busy state is managed by the caller.
  Future<AuthResult> _signInLocalDemo(String email) async {
    final user = AuthUser(
      id: _kLocalDemoUserId,
      email: email,
      name: 'Test Pilot',
      role: UserRole.student,
    );
    _accessToken = _kLocalDemoToken;
    _refreshToken = null;
    _userId = user.id;
    _currentUser = user;
    _isLocal = true;
    _supabaseSession = false;
    _guest = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessTokenKey, _accessToken!);
      await prefs.setString(_kUserIdKey, _userId!);
      await prefs.setBool(_kIsLocalKey, true);
      await prefs.setString(_kLocalEmailKey, user.email);
      await prefs.setString(_kLocalNameKey, user.name!);
    } catch (_) {
      // In-memory session still works for this run.
    }
    notifyListeners();
    return AuthResult.success(user);
  }

  /// Remove only the persisted local demo session keys (used when a real
  /// Supabase session takes over).
  Future<void> _clearLocalDemoSession() async {
    _isLocal = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsLocalKey);
      await prefs.remove(_kLocalEmailKey);
      await prefs.remove(_kLocalNameKey);
    } catch (_) {
      // Ignore — in-memory state is already updated.
    }
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

  /// Sign out and clear BOTH sessions: the Supabase session and the persisted
  /// local demo session (plus any legacy backend token). Best-effort network
  /// calls; clearing local state is what matters.
  Future<void> signOut() async {
    // Legacy backend token session → best-effort backend logout.
    final token = _accessToken;
    if (token != null && !_isLocal && !_supabaseSession) {
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

    // Sign out of Supabase (clears its persisted session on disk).
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Supabase unavailable/offline — local clear below still applies.
    }

    // Clear the native Google session so the next sign-in re-prompts the
    // account chooser (no silent re-login with the previous account).
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // No cached Google account / plugin unavailable — ignore.
    }

    _supabaseSession = false;
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
      return AuthUser(
        id: _userId!,
        email: '',
        name: null,
        role: UserRole.student,
      );
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
      final err = _str(map, [
        'error',
        'message',
        'detail',
        'error_description',
      ]);
      if (err != null && err.isNotEmpty) return err;
    }
    if (status == 401 || status == 403) {
      return 'Invalid credentials.';
    }
    return 'Request failed (HTTP $status).';
  }

  // ── Token storage ──────────────────────────────────────────────────────────────
  //
  // Tokens live in shared_preferences today — see the secure-storage note
  // at the top of this file.

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
    _isLocal = false;
    _guest = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessTokenKey);
      await prefs.remove(_kRefreshTokenKey);
      await prefs.remove(_kUserIdKey);
      await prefs.remove(_kIsLocalKey);
      await prefs.remove(_kLocalEmailKey);
      await prefs.remove(_kLocalNameKey);
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
