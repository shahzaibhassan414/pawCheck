/// A snapshot of the current device, gathered for [DeviceRepository] to
/// persist. [deviceType] is `'ios'` or `'android'` — this app is iOS-first
/// with Android as a fast-follow (CLAUDE.md), no other platform is
/// supported. [fcmToken] is null whenever a real push token isn't available
/// (currently always the case on iOS, since Push Notifications isn't
/// enabled as an Xcode capability yet — full notification handling is a
/// later PRD milestone; this just avoids sending a bogus token).
class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceType,
    required this.deviceId,
    required this.deviceName,
    this.fcmToken,
  });

  final String deviceType;
  final String deviceId;

  /// A human-readable label — the user-assigned device name on iOS (e.g.
  /// "Shahzaib's iPhone"), the hardware model on Android (e.g. "Pixel 7
  /// Pro"), since Android has no equivalent user-assigned name exposed by
  /// `device_info_plus`.
  final String deviceName;
  final String? fcmToken;
}

/// Resolves this device's identity for `DeviceRepository.recordDevice`. See
/// `PlatformDeviceInfoService` for the live implementation and
/// `FakeDeviceInfoService` for the canned fake every test must use instead
/// (same "never touch platform channels in tests" rule already followed for
/// `PhotoPickerFn`/`ImagePickerFn`).
abstract interface class DeviceInfoService {
  Future<DeviceIdentity> current();
}
