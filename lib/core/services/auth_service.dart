/// Email + OTP sign-in — no anonymous auth. A user's [String] email only
/// ever counts as signed-in once they've verified a code sent to it; see
/// `FirebaseAuthService` for the live implementation (backed by the
/// `/send-otp`/`/verify-otp` Cloudflare Worker in
/// `cloudflare/otp-worker/src/index.ts` — not Firebase Cloud Functions,
/// which require the Blaze billing plan just to deploy) and
/// `FakeAuthService` for the canned fake every test must inject instead
/// (same "never touch live services in tests" rule already followed for
/// `AiTriageService`).
abstract class AuthService {
  /// The signed-in user's email, or null if nobody's signed in. Resolves
  /// once any previously-persisted session has actually been restored —
  /// see `FirebaseAuthService`'s doc comment for why this can't just be a
  /// synchronous getter.
  Future<String?> resolveSignedInEmail();

  /// Sends a 6-digit code to [email]. Throws [AuthException] on failure
  /// (invalid email, rate-limited, couldn't send).
  Future<void> sendOtp(String email);

  /// Verifies [code] for [email] and, if correct, completes a real sign-in.
  /// Throws [AuthException] on an incorrect/expired code, too many
  /// attempts, or no pending code for that email.
  Future<void> verifyOtp({required String email, required String code});

  Future<void> signOut();
}
