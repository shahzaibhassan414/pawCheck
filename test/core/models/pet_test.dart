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
    );

    final roundTripped = Pet.fromJson(pet.toJson());

    expect(roundTripped, pet);
  });

  test('omits optional fields from JSON when null and restores them as null', () {
    const pet = Pet(id: 'pet-2', name: 'Whiskers', species: 'Cat');

    final json = pet.toJson();
    expect(json.containsKey('breed'), isFalse);
    expect(json.containsKey('age'), isFalse);

    final roundTripped = Pet.fromJson(json);
    expect(roundTripped.breed, isNull);
    expect(roundTripped.age, isNull);
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
