import 'package:flutter/foundation.dart';

import 'device_info_service.dart';
import 'device_repository.dart';

/// Best-effort: gathers this device's identity and records it via
/// [deviceRepository]. Swallows any failure (network, platform channel, a
/// permission-denied during a sign-out race, etc.) rather than letting it
/// propagate — call this with `unawaited(...)` right after a sign-in
/// resolves, since it must never block or fail that surrounding flow.
/// Logged via [debugPrint] purely for visibility during development; still
/// never surfaced to the user or rethrown.
///
/// Called from two places, both right after a `uid`/email becomes known:
/// `EmailVerificationScreen` (a brand-new sign-in, which never passes
/// through `SplashScreen`) and `SplashScreen` itself (every subsequent app
/// launch for an already-signed-in user).
Future<void> recordCurrentDevice({
  required DeviceInfoService deviceInfoService,
  required DeviceRepository deviceRepository,
}) async {
  try {
    final identity = await deviceInfoService.current();
    await deviceRepository.recordDevice(
      deviceId: identity.deviceId,
      deviceType: identity.deviceType,
      deviceName: identity.deviceName,
      fcmToken: identity.fcmToken,
    );
  } catch (error) {
    debugPrint('recordCurrentDevice failed: $error');
  }
}
