import '../models/pet.dart';

/// Reads and writes the signed-in user's pet profiles. Implementations must
/// scope every operation to the current uid — see `firestore.rules`'
/// `users/{uid}/**` rule, which is the actual security boundary this
/// interface's real implementation relies on.
///
/// [deletePet] must cascade-delete that pet's scans too (CLAUDE.md's data
/// model: "Deleting a pet must cascade-delete its scans — no orphaned
/// Firestore documents").
abstract class PetRepository {
  /// Live updates to the full pet list, most-recently-added order is not
  /// guaranteed — callers sort/display as needed.
  Stream<List<Pet>> watchPets();

  /// One-shot read, used by [SplashScreen] to decide onboarding vs. Home
  /// without holding a long-lived subscription open before the app has even
  /// rendered its first real screen.
  Future<List<Pet>> loadPetsOnce();

  Future<void> addPet(Pet pet);

  Future<void> updatePet(Pet pet);

  Future<void> deletePet(String petId);
}
