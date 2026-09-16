import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/services/in_memory_device_repository.dart';

void main() {
  test('recordDevice appends a record with the given fields', () async {
    final repository = InMemoryDeviceRepository();

    await repository.recordDevice(
      deviceId: 'device-1',
      deviceType: 'android',
      deviceName: 'Pixel 7',
      fcmToken: 'token-1',
    );

    expect(repository.recorded, hasLength(1));
    expect(repository.recorded.single.deviceId, 'device-1');
    expect(repository.recorded.single.deviceType, 'android');
    expect(repository.recorded.single.deviceName, 'Pixel 7');
    expect(repository.recorded.single.fcmToken, 'token-1');
  });

  test('recordDevice tolerates a null fcmToken', () async {
    final repository = InMemoryDeviceRepository();

    await repository.recordDevice(
      deviceId: 'device-1',
      deviceType: 'ios',
      deviceName: "Shahzaib's iPhone",
    );

    expect(repository.recorded.single.fcmToken, isNull);
  });

  test('repeat calls are all recorded, in order', () async {
    final repository = InMemoryDeviceRepository();

    await repository.recordDevice(
      deviceId: 'device-1',
      deviceType: 'android',
      deviceName: 'Pixel 7',
    );
    await repository.recordDevice(
      deviceId: 'device-1',
      deviceType: 'android',
      deviceName: 'Pixel 7',
    );

    expect(repository.recorded, hasLength(2));
  });
}
