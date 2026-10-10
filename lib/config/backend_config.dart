/// AmericanGroupLLC backend configuration.
///
/// Values here come from the official "AmericanGroupLLC Backend — Developer
/// Integration Guide". Everything in this file is a CLIENT-PUBLIC value
/// (API gateway URL, Supabase *anon/publishable* key, OAuth *client* IDs,
/// Firebase *project id*) — these are designed to ship inside client apps.
/// No server/service-role secrets are stored here.
///
/// Support / CORS / OAuth-callback whitelisting: support@americangroup.ai
class BackendConfig {
  BackendConfig._();

  /// The ONLY base URL the app should call.
  static const String apiBaseUrl = 'https://api.americangroupllc.com/api/v1';

  /// Developer support contact (from the integration guide, section 6).
  static const String supportEmail = 'support@americangroup.ai';

  // ── Supabase (direct DB access if ever needed; gateway is preferred) ──
  static const String supabaseUrl = 'https://smvvjivvlprjhzhoizym.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdnZqaXZ2bHByamh6aG9penltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMDIxMDMsImV4cCI6MjA5NTc3ODEwM30.csC-AHt-nI6BaZd6yt7imxbpAkS5tEOjqcpetZGWkF0';

  // ── Firebase (Phone OTP / SMS auth) ──
  static const String firebaseProjectId = 'americangroupllc-5bdfc';

  // ── Social login client IDs (native SDKs) ──
  static const String googleClientId =
      '146431650883-blpfddrf32ureu4ucqlp3oku9jo07luq.apps.googleusercontent.com';
  static const String facebookAppId = '1323978229267098';
  static const String twitterClientId = 'vcL1rnmUGnAfFCRIf3Czhdfj';
  static const String appleClientId = 'TLH7Z3G27A.com.americangroupllc.app';

  // ── Auth endpoints (note the literal `auth/auth` prefix from the guide) ──
  static const String registerPath = '/auth/auth/register';
  static const String loginPath = '/auth/auth/login';
  static const String refreshPath = '/auth/auth/refresh';
  static const String logoutPath = '/auth/auth/logout';
  static const String mePath = '/auth/me';
  static const String firebaseVerifyPath = '/auth/auth/firebase/verify';


  /// Backend AI assistant chat endpoint (requires Authorization).
  static const String aiChatPath = '/ai/chat';

}
