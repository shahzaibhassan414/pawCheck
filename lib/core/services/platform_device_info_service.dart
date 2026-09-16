import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'device_info_service.dart';

/// Real [DeviceInfoService]. Android's device id comes from `Settings.
/// Secure.ANDROID_ID` (via the `android_id` package — `device_info_plus`'s
/// own `AndroidDeviceInfo` deliberately doesn't expose a stable per-device
/// identifier, only build/OS fields like `fingerprint`); iOS's comes from
/// `identifierForVendor`, the standard non-IDFA per-vendor device id.
///
/// The FCM token is only fetched on Android: getting a real one on iOS
/// requires the Push Notifications Xcode capability + APNs registration,
/// which isn't enabled yet (push notification handling is a later PRD
/// milestone) — `FirebaseMessaging.instance.getToken()` would otherwise
/// throw there. Any fetch failure (missing Google Play Services, no
/// network, etc.) falls back to a null token rather than blocking or
/// failing the whole [current] call — this data is best-effort.
class PlatformDeviceInfoService implements DeviceInfoService {
  @override
  Future<DeviceIdentity> current() async {
    final deviceType = Platform.isIOS ? 'ios' : 'android';
    final deviceId = await _resolveDeviceId(deviceType);
    final deviceName = await _resolveDeviceName(deviceType);
    final fcmToken = deviceType == 'android' ? await _resolveFcmToken() : null;
    return DeviceIdentity(
      deviceType: deviceType,
      deviceId: deviceId,
      deviceName: deviceName,
      fcmToken: fcmToken,
    );
  }

  Future<String> _resolveDeviceId(String deviceType) async {
    if (deviceType == 'android') {
      final id = await const AndroidId().getId();
      return id ?? 'unknown-android-device';
    }
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.identifierForVendor ?? 'unknown-ios-device';
  }

  Future<String> _resolveDeviceName(String deviceType) async {
    if (deviceType == 'android') {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.model;
    }
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.name;
  }

  Future<String?> _resolveFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
