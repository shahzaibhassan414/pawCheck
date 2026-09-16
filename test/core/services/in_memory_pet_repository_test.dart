import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';

const _biscuit = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');
const _coco = Pet(id: 'pet-2', name: 'Coco', species: 'Cat');

void main() {
  test('loadPetsOnce reflects the seeded list', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit]);

    expect(await repository.loadPetsOnce(), [_biscuit]);
  });

  test('watchPets emits the current list immediately on listen', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit]);

    expect(await repository.watchPets().first, [_biscuit]);
  });

  test('addPet appends and is reflected in a subsequent read', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit]);

    await repository.addPet(_coco);

    expect(await repository.loadPetsOnce(), [_biscuit, _coco]);
  });

  test('addPet pushes an update to an already-listening watcher', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit]);
    final events = <List<Pet>>[];
    final subscription = repository.watchPets().listen(events.add);
    // Lets the stream's initial snapshot actually reach the listener before
    // triggering the mutation below — otherwise the two could race within
    // the same microtask and the update would coalesce into a single
    // emission instead of two distinct ones.
    await Future<void>.delayed(Duration.zero);

    await repository.addPet(_coco);
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      [_biscuit],
      [_biscuit, _coco],
    ]);
    await subscription.cancel();
  });

  test('updatePet replaces the pet with a matching id', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit]);

    await repository.updatePet(_biscuit.copyWith(name: 'Biscuit II'));

    final pets = await repository.loadPetsOnce();
    expect(pets, hasLength(1));
    expect(pets.single.name, 'Biscuit II');
  });

  test('deletePet removes only the matching pet', () async {
    final repository = InMemoryPetRepository(initialPets: [_biscuit, _coco]);

    await repository.deletePet(_biscuit.id);

    expect(await repository.loadPetsOnce(), [_coco]);
  });
}
