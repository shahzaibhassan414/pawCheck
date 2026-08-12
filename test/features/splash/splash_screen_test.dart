import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/onboarding/onboarding_screen.dart';
import 'package:paw_check/features/splash/splash_screen.dart';

void main() {
  Future<void> pumpSplash(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: SplashScreen()));

  testWidgets('renders the brand mark immediately on pump', (tester) async {
    await pumpSplash(tester);

    expect(find.byKey(const Key('splash_screen')), findsOneWidget);
    expect(find.text('PawCheck'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('navigates to OnboardingScreen once its animation finishes', (
    tester,
  ) async {
    await pumpSplash(tester);

    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
