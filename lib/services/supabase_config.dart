import 'package:flutter/foundation.dart' show kReleaseMode;

/// Central Supabase backend configuration for the AmericanGroupLLC platform.
///
/// The URL + anon (publishable) key are safe to ship in the client — the
/// publishable key only grants access allowed by Row Level Security policies.
///
/// The QA / Dev entries are supplied at build time and are empty in anything
/// shipped, so the one-tap "Use test account" path is inert in a release build.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://smvvjivvlprjhzhoizym.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdnZqaXZ2bHByamh6aG9penltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMDIxMDMsImV4cCI6MjA5NTc3ODEwM30.csC-AHt-nI6BaZd6yt7imxbpAkS5tEOjqcpetZGWkF0',
  );

  // Supplied at build time for internal/QA builds ONLY — never compiled into a
  // shipped binary:
  //
  //   flutter run --dart-define=QA_EMAIL=... --dart-define=QA_PASSWORD=...
  //
  // With no defines (the release default) every one of these is the empty
  // string and the whole test-account path is inert. Guard any use of them on
  // [testAccountEnabled]; never compare user input against them directly,
  // because '' == '' would otherwise authenticate an empty form.
  static const String qaEmail = String.fromEnvironment('QA_EMAIL');
  static const String qaPassword = String.fromEnvironment('QA_PASSWORD');
  static const String devEmail = String.fromEnvironment('DEV_EMAIL');
  static const String devPassword = String.fromEnvironment('DEV_PASSWORD');
  static const String adminEmail = String.fromEnvironment('ADMIN_EMAIL');
  static const String adminPassword = String.fromEnvironment('ADMIN_PASSWORD');

  /// True only in a non-release build that was actually given QA credentials.
  static bool get testAccountEnabled =>
      !kReleaseMode && qaEmail.isNotEmpty && qaPassword.isNotEmpty;

  /// True when a dev-tier define pair was supplied to a non-release build.
  static bool get devAccountEnabled =>
      !kReleaseMode && devEmail.isNotEmpty && devPassword.isNotEmpty;

  // ── Native OAuth client identifiers ────────────────────────────────────────
  // These are PUBLIC OAuth client IDs (safe to ship in the client binary — they
  // are not secrets). They are what the native Google / Apple SDKs and Supabase
  // use to mint and verify the ID tokens exchanged in the native token flow.

  /// Google **web / server** OAuth client id. Required as `serverClientId` so
  /// the native sign-in returns an `idToken` whose audience Supabase's Google
  /// provider trusts. Must match the "Client ID (for OAuth)" configured in the
  /// Supabase dashboard → Auth → Providers → Google. Overridable at build time
  /// via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '146431650883-blpfddrf32ureu4ucqlp3oku9jo07luq.apps.googleusercontent.com',
  );

  /// Google **iOS** OAuth client id (from `GoogleService-Info.plist`). Optional:
  /// when empty the native SDK falls back to the reversed-client-id URL scheme
  /// wired in `Info.plist`. Overridable via `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Apple Services ID (bundle/service identifier) and Developer Team ID used
  /// for "Sign in with Apple". The Services ID must be registered as the Apple
  /// provider's Client ID in the Supabase dashboard. On a real iOS device the
  /// native token flow uses the app's bundle id; these back the web/redirect
  /// fallback and the Supabase dashboard configuration.
  static const String appleServiceId = 'com.americangroupllc.app';
  static const String appleTeamId = 'TLH7Z3G27A';
}
