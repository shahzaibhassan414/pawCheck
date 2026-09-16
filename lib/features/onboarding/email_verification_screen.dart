import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/brand_assets.dart';
import '../../core/services/auth_exception.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_info_service.dart';
import '../../core/services/device_recording.dart';
import '../../core/services/device_repository.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_device_repository.dart';
import '../../core/services/firestore_pet_repository.dart';
import '../../core/services/firestore_scan_repository.dart';
import '../../core/services/pet_repository.dart';
import '../../core/services/platform_device_info_service.dart';
import '../../core/services/scan_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/labeled_field.dart';
import 'account_setup_screen.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/otp_code_field.dart';

enum _Step { email, sendingCode, code, verifying }

/// Email-OTP sign-in — shown right after onboarding (see
/// `OnboardingScreen._next()`) and before pet setup. Collects an email,
/// sends it a 6-digit code via [AuthService.sendOtp], then verifies the
/// code the user types back via [AuthService.verifyOtp]. That code is the
/// real credential behind every `users/{uid}/...` Firestore document, not
/// just a display string — `AccountSetupScreen` now requires an
/// already-verified `accountEmail` rather than collecting one itself.
class EmailVerificationScreen extends StatefulWidget {
  EmailVerificationScreen({
    super.key,
    AuthService? authService,
    PetRepository? petRepository,
    ScanRepository? scanRepository,
    DeviceInfoService? deviceInfoService,
    DeviceRepository? deviceRepository,
  }) : authService = authService ?? FirebaseAuthService(),
       petRepository = petRepository ?? FirestorePetRepository(),
       scanRepository = scanRepository ?? FirestoreScanRepository(),
       deviceInfoService = deviceInfoService ?? PlatformDeviceInfoService(),
       deviceRepository = deviceRepository ?? FirestoreDeviceRepository();

  /// Defaults to the real Firebase-backed services — every automated test
  /// must inject `FakeAuthService`/`InMemoryPetRepository`/
  /// `InMemoryScanRepository`/`FakeDeviceInfoService`/
  /// `InMemoryDeviceRepository` instead (same "never touch live services in
  /// tests" rule already followed for `AiTriageService`). [petRepository]/
  /// [scanRepository] are only used to hand off to the `AccountSetupScreen`
  /// this screen creates. [deviceInfoService]/[deviceRepository] record
  /// this device (see [recordCurrentDevice]) right after a successful
  /// verify — covers both sign-up and log-in, since this screen's
  /// [_EmailVerificationScreenState._verifyCode] is the one path both go
  /// through, unlike `SplashScreen`'s equivalent call which only fires on
  /// a later app launch, not this first sign-in itself.
  final AuthService authService;
  final PetRepository petRepository;
  final ScanRepository scanRepository;
  final DeviceInfoService deviceInfoService;
  final DeviceRepository deviceRepository;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

/// How long the "Resend code" button stays disabled after a send —
/// deliberately longer than the Worker's own 60s per-email cooldown
/// (`cloudflare/otp-worker/src/index.ts`'s `SEND_COOLDOWN_MS`), so the
/// button is never enabled only to have the server reject the request.
const _resendCooldown = Duration(minutes: 2);

String _formatCountdown(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  _Step _step = _Step.email;
  String? _error;
  String _verifiedEmail = '';
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendCooldown.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() {
      _step = _Step.sendingCode;
      _error = null;
    });
    try {
      await widget.authService.sendOtp(email);
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _verifiedEmail = email;
      });
      _startResendCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.email;
        _error = e.message;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _step = _Step.verifying;
      _error = null;
    });
    try {
      await widget.authService.verifyOtp(
        email: _verifiedEmail,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      // Fire-and-forget, same reasoning as `SplashScreen`'s equivalent
      // call — covers both sign-up and log-in (see class doc comment).
      unawaited(
        recordCurrentDevice(
          deviceInfoService: widget.deviceInfoService,
          deviceRepository: widget.deviceRepository,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AccountSetupScreen(
            accountEmail: _verifiedEmail,
            petRepository: widget.petRepository,
            scanRepository: widget.scanRepository,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _error = e.message;
      });
    }
  }

  void _changeEmail() {
    setState(() {
      _step = _Step.email;
      _codeController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCodeStep = _step == _Step.code || _step == _Step.verifying;
    final isBusy = _step == _Step.sendingCode || _step == _Step.verifying;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: isCodeStep
                    ? _CodeStep(
                        email: _verifiedEmail,
                        controller: _codeController,
                        error: _error,
                        onChangeEmail: isBusy ? null : _changeEmail,
                        onResend: isBusy || _resendSecondsRemaining > 0
                            ? null
                            : _sendCode,
                        resendSecondsRemaining: _resendSecondsRemaining,
                      )
                    : _EmailStep(controller: _emailController, error: _error),
              ),
              _BottomBar(
                busy: isBusy,
                label: isCodeStep ? 'Verify' : 'Send code',
                onPressed: isCodeStep ? _verifyCode : _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({required this.controller, required this.error});

  final TextEditingController controller;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceXl,
      ),
      child: Column(
        children: [
          FadeSlideIn(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Image.asset(BrandAssets.logo, width: 40, height: 40),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    "We'll send a 6-digit code to keep your pets' scans "
                    "backed up and private to your account.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: LabeledField(
              label: 'Email address',
              child: TextFormField(
                key: const Key('email_verification_email_field'),
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter your email';
                  final looksValid =
                      trimmed.contains('@') && trimmed.contains('.');
                  return looksValid ? null : 'Enter a valid email';
                },
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.email,
    required this.controller,
    required this.error,
    required this.onChangeEmail,
    required this.onResend,
    required this.resendSecondsRemaining,
  });

  final String email;
  final TextEditingController controller;
  final String? error;
  final VoidCallback? onChangeEmail;
  final VoidCallback? onResend;

  /// Seconds left in the resend cooldown — 0 once [onResend] is enabled.
  final int resendSecondsRemaining;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceXl,
      ),
      child: Column(
        children: [
          FadeSlideIn(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Enter your code',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'We sent a 6-digit code to $email.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: OtpCodeField(
              key: const Key('email_verification_code_field'),
              controller: controller,
              autofocus: true,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: const Key('email_verification_resend_button'),
                  onPressed: onResend,
                  child: const Text('Resend code'),
                ),
                TextButton(
                  key: const Key('email_verification_change_email_button'),
                  onPressed: onChangeEmail,
                  child: const Text('Change email'),
                ),
              ],
            ),
          ),
          if (resendSecondsRemaining > 0) ...[
            const SizedBox(height: AppTheme.spaceSm),
            FadeSlideIn(
              delay: const Duration(milliseconds: 190),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    child: LinearProgressIndicator(
                      key: const Key('email_verification_resend_progress'),
                      value: 1 - (resendSecondsRemaining / _resendCooldown.inSeconds),
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    '${_formatCountdown(resendSecondsRemaining)} remaining',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVerifyStep = label == 'Verify';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceLg,
          AppTheme.spaceMd,
          AppTheme.spaceLg,
          AppTheme.spaceMd,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: Key(
              isVerifyStep
                  ? 'email_verification_verify_button'
                  : 'email_verification_send_button',
            ),
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}
