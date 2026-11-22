/// Build-time configuration. Pass with
/// `--dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
/// Without them the app runs in local-only mode (no login, no sync).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _legacyAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Publishable key (new) or legacy anon key; both are safe to ship in a client.
  static String get supabaseKey => _publishable.isNotEmpty ? _publishable : _legacyAnon;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Deep link used by magic-link / password-reset emails.
  static const authRedirect = 'com.bayu.nudge://login-callback/';
}
