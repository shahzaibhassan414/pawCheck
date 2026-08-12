import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/onboarding/onboarding_screen.dart';
import 'package:paw_check/features/onboarding/pet_profile_form_screen.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: OnboardingScreen()),
  );

  testWidgets('renders the required not-a-vet disclaimer text', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'not a substitute for professional veterinary advice',
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Get started" on the last page opens the pet profile form', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PetProfileFormScreen), findsOneWidget);
  });
}
