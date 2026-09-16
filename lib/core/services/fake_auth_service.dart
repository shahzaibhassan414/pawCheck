import 'auth_exception.dart';
import 'auth_service.dart';

/// Fake [AuthService] for widget tests — every test that reaches
/// `SplashScreen`, `EmailVerificationScreen`, or a sign-out path must
/// inject this (or a configured instance of it) instead of the real
/// `FirebaseAuthService` (same "never touch live services in tests" rule
/// already followed for `AiTriageService`/`InMemoryPetRepository`).
///
/// [signedInEmail] seeds the initial [resolveSignedInEmail] result — pass
/// null for a signed-out user, an email for an already-signed-in returning
/// one. [sendOtpError]/[verifyOtpError], if set, make the matching call
/// throw that error instead of succeeding. Otherwise [sendOtp] "sends"
/// [fixedCode] (default `'123456'`) and [verifyOtp] only succeeds when the
/// submitted code matches it, mirroring the real Cloud Function's
/// wrong-code rejection.
class FakeAuthService implements AuthService {
  FakeAuthService({
    String? signedInEmail,
    this.fixedCode = '123456',
    this.sendOtpError,
    this.verifyOtpError,
  }) : _email = signedInEmail;

  String? _email;
  final String fixedCode;
  final Object? sendOtpError;
  final Object? verifyOtpError;

  /// The most recent email [sendOtp] was called with, for tests to assert
  /// on without needing their own spy.
  String? lastOtpEmail;

  @override
  Future<String?> resolveSignedInEmail() async => _email;

  @override
  Future<void> sendOtp(String email) async {
    lastOtpEmail = email;
    final error = sendOtpError;
    if (error != null) throw error;
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    final error = verifyOtpError;
    if (error != null) throw error;
    if (code != fixedCode) {
      throw const AuthException('That code is incorrect.');
    }
    _email = email;
  }

  @override
  Future<void> signOut() async {
    _email = null;
  }
}
