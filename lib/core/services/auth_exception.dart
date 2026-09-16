/// Thrown when sending or verifying an email OTP code fails — a wrong or
/// expired code, too many attempts, or the `sendOtp`/`verifyOtp` Cloud
/// Function call itself failing. [message] is written to be shown directly
/// to the user (see `FirebaseAuthService`, which maps Cloud Functions error
/// codes to one of these rather than leaking Functions-specific detail up
/// into the UI layer).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
