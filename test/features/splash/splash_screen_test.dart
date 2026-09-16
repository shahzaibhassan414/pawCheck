import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/fake_auth_service.dart';
import 'package:paw_check/core/services/fake_device_info_service.dart';
import 'package:paw_check/core/services/in_memory_device_repository.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';
import 'package:paw_check/features/onboarding/account_setup_screen.dart';
import 'package:paw_check/features/onboarding/onboarding_screen.dart';
import 'package:paw_check/features/scan/home_screen.dart';
import 'package:paw_check/features/splash/splash_screen.dart';

const _biscuit = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    List<Pet> seededPets = const [],
    String? signedInEmail,
    InMemoryDeviceRepository? deviceRepository,
  }) => tester.pumpWidget(
    MaterialApp(
      home: SplashScreen(
        authService: FakeAuthService(signedInEmail: signedInEmail),
        petRepository: InMemoryPetRepository(initialPets: seededPets),
        scanRepository: InMemoryScanRepository(),
        deviceInfoService: FakeDeviceInfoService(),
        deviceRepository: deviceRepository ?? InMemoryDeviceRepository(),
      ),
    ),
  );

  testWidgets('renders the brand mark immediately on pump', (tester) async {
    await pumpSplash(tester);

    expect(find.byKey(const Key('splash_screen')), findsOneWidget);
    expect(find.text('PawCheck'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets(
    'navigates to OnboardingScreen once its animation finishes, for a new user',
    (tester) async {
      await pumpSplash(tester);

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'navigates straight to Home once its animation finishes, for a returning user',
    (tester) async {
      await pumpSplash(
        tester,
        seededPets: [_biscuit],
        signedInEmail: 'test@example.com',
      );

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Scan Biscuit'), findsOneWidget);
    },
  );

  testWidgets(
    'navigates to AccountSetupScreen once its animation finishes, for a '
    'signed-in user with no pets yet (an interrupted setup)',
    (tester) async {
      await pumpSplash(tester, signedInEmail: 'test@example.com');

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(AccountSetupScreen), findsOneWidget);
    },
  );

  testWidgets(
    'records this device for a signed-in user, once navigation settles',
    (tester) async {
      final deviceRepository = InMemoryDeviceRepository();

      await pumpSplash(
        tester,
        seededPets: [_biscuit],
        signedInEmail: 'test@example.com',
        deviceRepository: deviceRepository,
      );
      await tester.pumpAndSettle();

      expect(deviceRepository.recorded, hasLength(1));
      expect(deviceRepository.recorded.single.deviceId, 'test-device-id');
      expect(deviceRepository.recorded.single.deviceType, 'android');
      expect(deviceRepository.recorded.single.fcmToken, 'test-fcm-token');
    },
  );

  testWidgets('does not record a device for a not-signed-in user', (
    tester,
  ) async {
    final deviceRepository = InMemoryDeviceRepository();

    await pumpSplash(tester, deviceRepository: deviceRepository);
    await tester.pumpAndSettle();

    expect(deviceRepository.recorded, isEmpty);
  });

  testWidgets('tapping the screen navigates immediately, without waiting', (
    tester,
  ) async {
    await pumpSplash(
      tester,
      seededPets: [_biscuit],
      signedInEmail: 'test@example.com',
    );

    await tester.tap(find.byKey(const Key('splash_screen')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
