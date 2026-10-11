import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
        PostgrestException,
        User;

import 'supabase_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — REAL client against the org's Supabase backend.
//
// Email/password sign-in goes through Supabase Auth
// (`Supabase.instance.client.auth.signInWithPassword`). Supabase persists and
// auto-restores its own session, so a networked device always uses the real
// backend.
//
// Google and Apple sign-in exchange their native ID tokens with Supabase Auth
// as well. The old AmericanGroupLLC API gateway no longer exists, so nothing
// here calls it; a token persisted by a build that did is discarded on launch.
//
// Offline: when the device cannot reach Supabase (network/socket error),
// email/password sign-in fails with a network error. See [loginEmail].
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

  // ── State ────────────────────────────────────────────────────────────────────
  String? _accessToken;
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

  /// True for a session restored from an older build's offline sign-in.
  /// Nothing creates one any more; existing ones are still honoured.
  bool get isLocalSession => _isLocal;

  /// True when the user chose to browse without signing in.
  bool get isGuest => _guest;

  /// The gate should show the main app when authenticated OR browsing as guest.
  bool get canEnterApp => isAuthenticated || _guest;


  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Restore any persisted session, then best-effort refresh the profile.
  /// Safe to call multiple times.
  ///
  /// Precedence: a live Supabase session (auto-restored by the SDK on a
  /// networked device) wins; otherwise a persisted local demo session; otherwise
  /// signed out. A token stored by an older build for the retired API gateway
  /// is discarded: that server no longer exists, so the token proves nothing.
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
          // Fall back to a neutral placeholder rather than rendering an empty
          // address.
          email: prefs.getString(_kLocalEmailKey) ?? 'demo@local',
          name: prefs.getString(_kLocalNameKey) ?? 'Test Pilot',
          role: UserRole.student,
        );
      } else {
        // Token left behind by an older build's retired API gateway login.
        // Nothing can validate it any more, so drop it instead of treating
        // it as a signed-in session.
        if (prefs.containsKey(_kAccessTokenKey) ||
            prefs.containsKey(_kRefreshTokenKey)) {
          await prefs.remove(_kAccessTokenKey);
          await prefs.remove(_kRefreshTokenKey);
          await prefs.remove(_kUserIdKey);
        }
        _accessToken = null;
        _userId = null;
      }
    } catch (_) {
      // Corrupt/unavailable prefs — treat as signed out, never crash.
      _accessToken = null;
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
  }

  // ── Email / password ──────────────────────────────────────────────────────────

  /// Email/password sign-up via the org's Supabase Auth backend.
  ///
  /// This used to POST to `BackendConfig.registerPath` on
  /// api.americangroupllc.com, a host with no DNS record, so sign-up could
  /// never succeed while sign-in (already Supabase) worked. The project
  /// requires email confirmation, so a new account normally comes back with
  /// no session: the user is told to confirm, then sign in.
  Future<AuthResult> registerEmail(
    String email,
    String password, {
    String? name,
  }) async {
    final normalizedEmail = email.trim();
    final trimmedName = name?.trim() ?? '';
    _setBusy(true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: trimmedName.isEmpty
            ? null
            : {'name': trimmedName, 'full_name': trimmedName},
      );
      final sUser = response.user;
      final sSession = response.session;
      if (sUser == null) {
        return const AuthResult.failure('Could not create the account.');
      }
      if (sSession == null) {
        return const AuthResult.failure(
          'Check your email to confirm your account, then sign in.',
        );
      }
      return await _adoptSupabaseSession(response);
    } on AuthRetryableFetchException {
      return _networkFallback();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return _networkFallback();
    } finally {
      _setBusy(false);
    }
  }

  /// Email/password sign-in via the org's Supabase Auth backend.
  ///
  /// A networked device always authenticates against Supabase. When the device
  /// cannot reach Supabase (network/socket error) sign-in fails with a network
  /// error. A genuine Supabase [AuthException] (bad credentials, unconfirmed
  /// email, etc.) is returned as-is.
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
      return await _adoptSupabaseSession(response);
    } on AuthRetryableFetchException {
      // Retryable transport failure (couldn't reach Supabase). Treat as an
      // offline/network error.
      return _networkFallback();
    } on AuthException catch (e) {
      // Definitive rejection from Supabase (bad credentials, etc.).
      return AuthResult.failure(e.message);
    } catch (_) {
      // SocketException / http ClientException / TimeoutException / any other
      // transport failure — same offline handling as above.
      return _networkFallback();
    } finally {
      _setBusy(false);
    }
  }

  /// Offline path: Supabase is unreachable, so sign-in fails with a normal
  /// network error.
  AuthResult _networkFallback() {
    return const AuthResult.failure(
      'Network error. Check your connection and try again.',
    );
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

  /// Whether "Continue with Google" can work on [platform]. On iOS and macOS
  /// the native SDK needs an iOS OAuth client id (GOOGLE_IOS_CLIENT_ID, or
  /// GIDClientID in Info.plist); this build has neither, so the button is not
  /// offered there rather than failing after the tap.
  static bool googleSignInAvailableOn(
    TargetPlatform platform, {
    String iosClientId = SupabaseConfig.googleIosClientId,
  }) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return iosClientId.trim().isNotEmpty;
    }
    return true;
  }

  /// [googleSignInAvailableOn] for the platform the app is running on.
  static bool get googleSignInAvailable =>
      googleSignInAvailableOn(defaultTargetPlatform);

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

  /// Sign out and clear BOTH sessions: the Supabase session and the persisted
  /// local session. Clearing local state is what matters.
  Future<void> signOut() async {
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

  // ── Account deletion ─────────────────────────────────────────────────────────

  /// Profile details the user typed on the Profile screen. They describe the
  /// person who owns the account, so they go with it.
  static const List<String> _kProfilePrefKeys = <String>[
    'profile_name',
    'profile_cert',
    'profile_level',
    'profile_medical',
    'profile_medical_expiry',
    'profile_bfr_expiry',
  ];

  /// Deletes the signed-in account on the server, then signs out and clears
  /// the account's locally stored details. Replaced in tests only.
  @visibleForTesting
  Future<void> Function() deleteUserOnServer = () async {
    // public.delete_user() deletes the caller (auth.uid()) — see
    // AmericanGroupLLC-Backend/supabase/migrations/20261009_delete_user.sql.
    await Supabase.instance.client.rpc('delete_user');
  };

  /// Permanently deletes the account (App Store 5.1.1(v)).
  ///
  /// Success is reported only after the server confirms the delete. If the
  /// call fails the user stays signed in and the error is returned, so the UI
  /// never claims an account is gone when it is not.
  Future<AuthResult> deleteAccount() async {
    _setBusy(true);
    try {
      await deleteUserOnServer();
    } on PostgrestException catch (e) {
      _setBusy(false);
      return AuthResult.failure('Could not delete your account: ${e.message}');
    } catch (e) {
      _setBusy(false);
      return AuthResult.failure('Could not delete your account: $e');
    }
    await signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _kProfilePrefKeys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // The account is already gone on the server; nothing to undo.
    }
    _setBusy(false);
    return const AuthResult(true);
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

  Future<void> _clearTokens() async {
    _accessToken = null;
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
