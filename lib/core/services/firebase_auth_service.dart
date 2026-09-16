import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'auth_exception.dart';
import 'auth_service.dart';

/// Real [AuthService] — `sendOtp`/`verifyOtp` call a Cloudflare Worker
/// (`cloudflare/otp-worker/`, at [Env.otpWorkerBaseUrl]) that generates/emails
/// a 6-digit code via Brevo and, once verified, mints a custom sign-in token
/// for a Firebase Auth user found or created for that email. Not Firebase
/// Cloud Functions — those require the Blaze billing plan (a card on file)
/// just to deploy, which this project avoids entirely.
class FirebaseAuthService implements AuthService {
  @override
  Future<String?> resolveSignedInEmail() async {
    // Not `FirebaseAuth.instance.currentUser` — native Firebase Auth
    // restores a persisted session asynchronously in the background, so
    // reading `currentUser` synchronously right after `Firebase.
    // initializeApp()` can incorrectly report null for an already-signed-in
    // returning user. The stream's first event is the SDK's definitive
    // "session restore finished" signal.
    final user = await FirebaseAuth.instance.authStateChanges().first;
    return user?.email;
  }

  @override
  Future<void> sendOtp(String email) async {
    await _post('/send-otp', {'email': email});
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    final data = await _post('/verify-otp', {'email': email, 'code': code});
    final token = data['token'] as String;
    await FirebaseAuth.instance.signInWithCustomToken(token);
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('${Env.otpWorkerBaseUrl}$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const AuthException(
        "Something went wrong. Check your connection and try again.",
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = data['message'] as String?;
      throw AuthException(
        message != null && message.isNotEmpty
            ? message
            : "Something went wrong. Check your connection and try again.",
      );
    }
    return data;
  }
}
