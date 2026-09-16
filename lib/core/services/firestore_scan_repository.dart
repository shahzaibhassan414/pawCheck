import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/scan.dart';
import 'firestore_stream_utils.dart';
import 'scan_repository.dart';

/// Real [ScanRepository], backed by `users/{email}/pets/{petId}/scans` — the
/// document id is the signed-in account's own (lowercased) email, not the
/// Firebase Auth uid (see `FirestorePetRepository`'s doc comment for why).
/// Only ever constructed after `AuthService.resolveSignedInEmail()` has
/// resolved to a real, email-OTP-verified account (see `SplashScreen`/
/// `EmailVerificationScreen`), so `currentUser` and its `email` are
/// guaranteed non-null here.
class FirestoreScanRepository implements ScanRepository {
  CollectionReference<Map<String, dynamic>> _scans(String petId) {
    final email = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('pets')
        .doc(petId)
        .collection('scans');
  }

  @override
  Stream<List<Scan>> watchScans(String petId) {
    return _scans(
      petId,
    ).snapshots().handleError(ignorePermissionDeniedDuringSignOut).map(
      (snapshot) =>
          snapshot.docs.map((doc) => Scan.fromJson(doc.data())).toList(),
    );
  }

  @override
  Future<void> addScan(String petId, Scan scan) =>
      _scans(petId).doc(scan.id).set(scan.toJson());

  @override
  Future<void> deleteScan(String petId, String scanId) =>
      _scans(petId).doc(scanId).delete();
}
