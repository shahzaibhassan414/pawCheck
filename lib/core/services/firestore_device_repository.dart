import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'device_repository.dart';

/// Real [DeviceRepository], backed by `users/{email}/devices/{deviceId}` —
/// the document id is the signed-in account's own (lowercased) email, not
/// the Firebase Auth uid (see `FirestorePetRepository`'s doc comment for
/// why). Only ever constructed after a real, email-OTP-verified sign-in
/// (see `SplashScreen`), so `currentUser` and its `email` are guaranteed
/// non-null here.
class FirestoreDeviceRepository implements DeviceRepository {
  @override
  Future<void> recordDevice({
    required String deviceId,
    required String deviceType,
    required String deviceName,
    String? fcmToken,
  }) {
    final email = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('devices')
        .doc(deviceId)
        .set({
          'deviceId': deviceId,
          'deviceType': deviceType,
          'deviceName': deviceName,
          'fcmToken': fcmToken,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
  }
}
