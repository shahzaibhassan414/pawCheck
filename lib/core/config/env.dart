/// Reads secrets passed at build/run time via
/// `--dart-define-from-file=env.json` (copy `env.example.json` to `env.json`
/// and fill in real values — `env.json` is gitignored, never commit it).
abstract final class Env {
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const revenueCatApiKeyIos = String.fromEnvironment(
    'REVENUECAT_API_KEY_IOS',
  );

  static const revenueCatApiKeyAndroid = String.fromEnvironment(
    'REVENUECAT_API_KEY_ANDROID',
  );
}
