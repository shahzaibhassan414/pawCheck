import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/pet.dart';

void main() {
  test('serializes to JSON and back without data loss', () {
    const pet = Pet(
      id: 'pet-1',
      name: 'Biscuit',
      species: 'Dog',
      breed: 'Beagle',
      age: 3,
      photoUrl: 'data:image/jpeg;base64,abc123',
      gender: 'Male',
    );

    final roundTripped = Pet.fromJson(pet.toJson());

    expect(roundTripped, pet);
  });

  test(
    'omits optional fields from JSON when null and restores them as null',
    () {
      const pet = Pet(id: 'pet-2', name: 'Whiskers', species: 'Cat');

      final json = pet.toJson();
      expect(json.containsKey('breed'), isFalse);
      expect(json.containsKey('age'), isFalse);
      expect(json.containsKey('photoUrl'), isFalse);
      expect(json.containsKey('gender'), isFalse);

      final roundTripped = Pet.fromJson(json);
      expect(roundTripped.breed, isNull);
      expect(roundTripped.age, isNull);
      expect(roundTripped.photoUrl, isNull);
      expect(roundTripped.gender, isNull);
    },
  );

  group('copyWith', () {
    test('overrides gender to a new value', () {
      const pet = Pet(id: 'pet-5', name: 'Milo', species: 'Dog');

      expect(pet.copyWith(gender: 'Male').gender, 'Male');
    });

    test(
      'cannot clear gender back to null — a null argument keeps the '
      'existing value, since copyWith merges with `field ?? this.field` '
      '(this is why edit-mode pet saves build a new Pet directly instead '
      'of using copyWith — see PetFormScreen._submit)',
      () {
        const pet = Pet(
          id: 'pet-6',
          name: 'Nala',
          species: 'Cat',
          gender: 'Female',
        );

        expect(pet.copyWith(gender: null).gender, 'Female');
      },
    );
  });

  group('fromJson failure handling', () {
    test('throws a catchable FormatException for a missing required field', () {
      final json = {'id': 'pet-3', 'species': 'Dog'}; // missing name

      expect(() => Pet.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('throws a catchable FormatException for a wrong-typed field', () {
      final json = {'id': 'pet-4', 'name': 'Rex', 'species': 42};

      expect(() => Pet.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
