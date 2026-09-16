import 'dart:async';

import '../models/scan.dart';
import 'scan_repository.dart';

/// Fake [ScanRepository] for widget tests — see
/// [InMemoryPetRepository]'s doc comment for why every test must inject
/// this instead of the real Firestore-backed default.
class InMemoryScanRepository implements ScanRepository {
  InMemoryScanRepository({Map<String, List<Scan>>? initialScans})
    : _scansByPet = {
        for (final entry in (initialScans ?? const {}).entries)
          entry.key: List.of(entry.value),
      };

  final Map<String, List<Scan>> _scansByPet;
  final _controllers = <String, StreamController<List<Scan>>>{};

  StreamController<List<Scan>> _controllerFor(String petId) =>
      _controllers.putIfAbsent(petId, () => StreamController.broadcast());

  List<Scan> _listFor(String petId) => _scansByPet.putIfAbsent(petId, () => []);

  @override
  Stream<List<Scan>> watchScans(String petId) async* {
    yield List.unmodifiable(_listFor(petId));
    yield* _controllerFor(petId).stream;
  }

  @override
  Future<void> addScan(String petId, Scan scan) async {
    _listFor(petId).add(scan);
    _controllerFor(petId).add(List.unmodifiable(_listFor(petId)));
  }

  @override
  Future<void> deleteScan(String petId, String scanId) async {
    _listFor(petId).removeWhere((s) => s.id == scanId);
    _controllerFor(petId).add(List.unmodifiable(_listFor(petId)));
  }
}
