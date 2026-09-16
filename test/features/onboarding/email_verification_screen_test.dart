import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/services/auth_exception.dart';
import 'package:paw_check/core/services/fake_auth_service.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';
import 'package:paw_check/features/onboarding/account_setup_screen.dart';
import 'package:paw_check/features/onboarding/email_verification_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, FakeAuthService authService) =>
      tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            authService: authService,
            petRepository: InMemoryPetRepository(),
            scanRepository: InMemoryScanRepository(),
          ),
        ),
      );

  Future<void> sendCode(WidgetTester tester, {String email = 'a@b.com'}) async {
    await tester.enterText(
      find.byKey(const Key('email_verification_email_field')),
      email,
    );
    await tester.tap(find.byKey(const Key('email_verification_send_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an invalid email format before sending', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);

    await sendCode(tester, email: 'not-an-email');

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(auth.lastOtpEmail, isNull);
    expect(
      find.byKey(const Key('email_verification_code_field')),
      findsNothing,
    );
  });

  testWidgets('sends a code and advances to the code step', (tester) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);

    await sendCode(tester, email: 'a@b.com');

    expect(auth.lastOtpEmail, 'a@b.com');
    expect(
      find.byKey(const Key('email_verification_code_field')),
      findsOneWidget,
    );
    expect(find.textContaining('a@b.com'), findsOneWidget);
  });

  testWidgets('shows a send error inline and stays on the email step', (
    tester,
  ) async {
    final auth = FakeAuthService(
      sendOtpError: const AuthException(
        'Please wait a moment before requesting another code.',
      ),
    );
    await pumpScreen(tester, auth);

    await sendCode(tester);

    expect(
      find.text('Please wait a moment before requesting another code.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('email_verification_email_field')),
      findsOneWidget,
    );
  });

  testWidgets('wrong code shows an inline error and does not navigate', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);
    await sendCode(tester);

    await tester.enterText(
      find.byKey(const Key('email_verification_code_field')),
      '000000',
    );
    await tester.tap(
      find.byKey(const Key('email_verification_verify_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
    expect(find.byType(AccountSetupScreen), findsNothing);
  });

  testWidgets(
    'correct code navigates to AccountSetupScreen with the verified email',
    (tester) async {
      final auth = FakeAuthService();
      await pumpScreen(tester, auth);
      await sendCode(tester, email: 'a@b.com');

      await tester.enterText(
        find.byKey(const Key('email_verification_code_field')),
        auth.fixedCode,
      );
      await tester.tap(
        find.byKey(const Key('email_verification_verify_button')),
      );
      await tester.pumpAndSettle();

      final screen = tester.widget<AccountSetupScreen>(
        find.byType(AccountSetupScreen),
      );
      expect(screen.accountEmail, 'a@b.com');
    },
  );

  testWidgets('change email returns to the email step', (tester) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);
    await sendCode(tester);

    await tester.tap(
      find.byKey(const Key('email_verification_change_email_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('email_verification_email_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('email_verification_code_field')),
      findsNothing,
    );
  });

  testWidgets('resend re-calls sendOtp for the same email', (tester) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);
    await sendCode(tester, email: 'a@b.com');

    await tester.tap(
      find.byKey(const Key('email_verification_resend_button')),
    );
    await tester.pumpAndSettle();

    expect(auth.lastOtpEmail, 'a@b.com');
    expect(
      find.byKey(const Key('email_verification_code_field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'resend shows a live m:ss countdown and is disabled until it elapses',
    (tester) async {
      final auth = FakeAuthService();
      await pumpScreen(tester, auth);

      // Deliberately not the `sendCode` helper's `pumpAndSettle` — that
      // would fast-forward straight through the whole cooldown, since it
      // keeps pumping as long as the Timer's own setState calls schedule
      // new frames. Two plain pumps are enough to let `sendOtp`'s awaited
      // Future resolve and land its setState.
      await tester.enterText(
        find.byKey(const Key('email_verification_email_field')),
        'a@b.com',
      );
      await tester.tap(
        find.byKey(const Key('email_verification_send_button')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text('2:00 remaining'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('email_verification_resend_button')),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 65));
      expect(find.text('0:55 remaining'), findsOneWidget);

      await tester.pump(const Duration(seconds: 55));
      expect(find.textContaining('remaining'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('email_verification_resend_button')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}
