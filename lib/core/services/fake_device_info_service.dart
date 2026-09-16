import 'device_info_service.dart';

/// Fake [DeviceInfoService] for widget tests — every test that reaches
/// `SplashScreen`'s device-recording step must inject this instead of the
/// real `PlatformDeviceInfoService`, which touches platform channels.
class FakeDeviceInfoService implements DeviceInfoService {
  FakeDeviceInfoService({
    this.identity = const DeviceIdentity(
      deviceType: 'android',
      deviceId: 'test-device-id',
      deviceName: 'Test Device',
      fcmToken: 'test-fcm-token',
    ),
  });

  final DeviceIdentity identity;

  @override
  Future<DeviceIdentity> current() async => identity;
}
