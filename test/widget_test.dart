import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/services/fake_auth_service.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/features/splash/splash_screen.dart';
import 'package:paw_check/main.dart';

void main() {
  testWidgets('app launches into the splash screen, then onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        authService: FakeAuthService(),
        petRepository: InMemoryPetRepository(),
      ),
    );

    // Splash is the very first frame — onboarding hasn't appeared yet.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('A second look, in plain language'), findsNothing);

    // Advance past the splash's bounded entrance + hold, then let the
    // pushReplacement transition settle.
    await tester.pump(SplashScreen.totalDuration);
    await tester.pumpAndSettle();

    expect(find.text('A second look, in plain language'), findsOneWidget);
  });
}
