/// Central Supabase backend configuration for the AmericanGroupLLC platform.
///
/// The URL + anon (publishable) key are safe to ship in the client — the
/// publishable key only grants access allowed by Row Level Security policies.
///
/// The QA / Dev entries are the shared test accounts provisioned in the backend
/// for automated + manual testing (per the org integration guide). They power the
/// one-tap "Use test account" button on the login screen.
class SupabaseConfig {
  static const String url = 'https://smvvjivvlprjhzhoizym.supabase.co';
  static const String anonKey =
      'sb_publishable_nqtYGp48NKiRF53zivkpsQ_bRiqDSfc';

  static const String qaEmail = 'qa@safecodeg.com';
  static const String qaPassword = 'QATest@2026!';
  static const String devEmail = 'dev@safecodeg.com';
  static const String devPassword = 'DevTest@2026!';
}
