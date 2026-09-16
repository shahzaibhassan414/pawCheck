import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/onboarding/email_verification_screen.dart';
import 'package:paw_check/features/onboarding/onboarding_screen.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

  testWidgets('renders the required not-a-vet disclaimer text on step 1', (
    tester,
  ) async {
    // Per the "Paw Check claude design" doc, the disclaimer is folded into
    // step 1's expectations-setting body copy rather than given its own
    // page — so it's visible immediately, no tap needed.
    await pumpOnboarding(tester);

    expect(
      find.textContaining(
        'not a substitute for professional veterinary advice',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping Continue three times (one per step) opens the email '
    'verification screen',
    (tester) async {
      await pumpOnboarding(tester);

      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    },
  );

  testWidgets('no back button on step 1; it appears and works from step 2', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.byKey(const Key('onboarding_back_button')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding_back_button')), findsOneWidget);
    expect(find.text('Snap a photo, get clarity'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_back_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('A calm second opinion for your pet'),
      findsOneWidget,
    );
  });
}
