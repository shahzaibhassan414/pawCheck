/// Records the current device's identity for push-notification targeting.
/// Written per-device (a user may have more than one) under
/// `users/{email}/devices/{deviceId}`, so a signed-in user's devices don't
/// overwrite one another.
abstract class DeviceRepository {
  Future<void> recordDevice({
    required String deviceId,
    required String deviceType,
    required String deviceName,
    String? fcmToken,
  });
}
