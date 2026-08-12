import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/splash/splash_screen.dart';
import 'package:paw_check/main.dart';

void main() {
  testWidgets('app launches into the splash screen, then onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // Splash is the very first frame — onboarding hasn't appeared yet.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Snap a photo, get instant clarity'), findsNothing);

    // Advance past the splash's bounded entrance + hold, then let the
    // pushReplacement transition settle.
    await tester.pump(SplashScreen.totalDuration);
    await tester.pumpAndSettle();

    expect(
      find.text('Snap a photo, get instant clarity'),
      findsOneWidget,
    );
  });
}
