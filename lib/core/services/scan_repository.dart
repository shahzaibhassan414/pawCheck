import '../models/scan.dart';

/// Reads and writes a single pet's scan history. Implementations must scope
/// every operation under that pet's document — see `firestore.rules`' and
/// [PetRepository.deletePet]'s cascade-delete, which relies on scans always
/// living at `users/{uid}/pets/{petId}/scans`.
abstract class ScanRepository {
  Stream<List<Scan>> watchScans(String petId);

  Future<void> addScan(String petId, Scan scan);

  Future<void> deleteScan(String petId, String scanId);
}
