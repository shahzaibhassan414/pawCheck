import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/services/auth_service.dart';
import 'core/services/pet_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  /// [authService]/[petRepository], if given, are forwarded to
  /// [SplashScreen] — every automated test must inject `FakeAuthService`/
  /// `InMemoryPetRepository` instead of letting Splash default to the real
  /// Firebase-backed ones (same "never touch live services in tests" rule
  /// already followed for `AiTriageService`).
  const MyApp({super.key, this.authService, this.petRepository});

  final AuthService? authService;
  final PetRepository? petRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PawCheck',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: SplashScreen(authService: authService, petRepository: petRepository),
    );
  }
}
