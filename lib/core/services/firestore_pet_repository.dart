import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pet.dart';
import 'firestore_stream_utils.dart';
import 'pet_repository.dart';

/// Real [PetRepository], backed by `users/{email}/pets` — the document id is
/// the signed-in account's own (lowercased) email, not the Firebase Auth
/// uid, so the structure reads cleanly in the Firestore console: `users` →
/// one document per account, named by its email → that account's data
/// nested underneath. Only ever constructed after
/// `AuthService.resolveSignedInEmail()` has resolved to a real,
/// email-OTP-verified account (see `SplashScreen`/`EmailVerificationScreen`),
/// so `currentUser` and its `email` are guaranteed non-null here.
class FirestorePetRepository implements PetRepository {
  CollectionReference<Map<String, dynamic>> get _pets {
    final email = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('pets');
  }

  @override
  Stream<List<Pet>> watchPets() {
    return _pets.snapshots().handleError(ignorePermissionDeniedDuringSignOut).map(
      (snapshot) =>
          snapshot.docs.map((doc) => Pet.fromJson(doc.data())).toList(),
    );
  }

  @override
  Future<List<Pet>> loadPetsOnce() async {
    final snapshot = await _pets.get();
    return snapshot.docs.map((doc) => Pet.fromJson(doc.data())).toList();
  }

  @override
  Future<void> addPet(Pet pet) => _pets.doc(pet.id).set(pet.toJson());

  @override
  Future<void> updatePet(Pet pet) => _pets.doc(pet.id).set(pet.toJson());

  @override
  Future<void> deletePet(String petId) async {
    final scans = await _pets.doc(petId).collection('scans').get();
    const chunkSize = 400;
    for (var i = 0; i < scans.docs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in scans.docs.skip(i).take(chunkSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _pets.doc(petId).delete();
  }
}
