import 'dart:async';

import '../models/pet.dart';
import 'pet_repository.dart';

/// Fake [PetRepository] for widget tests — every test that constructs a
/// screen touching pets must inject this (or a seeded instance of it)
/// instead of relying on the default [FirestorePetRepository], the same way
/// every `ScanScreen` test already injects `MockAiTriageService` rather than
/// hitting the live Gemini API (PRD Section 12: never call live services in
/// automated tests).
class InMemoryPetRepository implements PetRepository {
  InMemoryPetRepository({List<Pet> initialPets = const []})
    : _pets = List.of(initialPets);

  final List<Pet> _pets;
  final _controller = StreamController<List<Pet>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_pets));

  @override
  Stream<List<Pet>> watchPets() async* {
    yield List.unmodifiable(_pets);
    yield* _controller.stream;
  }

  @override
  Future<List<Pet>> loadPetsOnce() async => List.unmodifiable(_pets);

  @override
  Future<void> addPet(Pet pet) async {
    _pets.add(pet);
    _emit();
  }

  @override
  Future<void> updatePet(Pet pet) async {
    final index = _pets.indexWhere((p) => p.id == pet.id);
    if (index != -1) _pets[index] = pet;
    _emit();
  }

  @override
  Future<void> deletePet(String petId) async {
    _pets.removeWhere((p) => p.id == petId);
    _emit();
  }
}
