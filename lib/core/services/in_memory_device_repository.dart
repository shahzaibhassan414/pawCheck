import 'device_repository.dart';

/// Fake [DeviceRepository] for widget tests — every test touching device
/// recording must inject this instead of the real
/// [FirestoreDeviceRepository], same "never touch live services in tests"
/// rule already followed for [PetRepository]/[AiTriageService].
class InMemoryDeviceRepository implements DeviceRepository {
  /// Every call this fake has recorded, in order — tests assert on the last
  /// entry (or the full history, for repeat-call behavior) rather than
  /// needing their own spy.
  final List<
    ({String deviceId, String deviceType, String deviceName, String? fcmToken})
  >
  recorded = [];

  @override
  Future<void> recordDevice({
    required String deviceId,
    required String deviceType,
    required String deviceName,
    String? fcmToken,
  }) async {
    recorded.add((
      deviceId: deviceId,
      deviceType: deviceType,
      deviceName: deviceName,
      fcmToken: fcmToken,
    ));
  }
}
