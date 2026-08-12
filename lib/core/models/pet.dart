class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.age,
  });

  final String id;
  final String name;
  final String species;
  final String? breed;
  final int? age;

  /// Throws [FormatException] on missing/invalid required fields rather
  /// than crashing — callers (Firestore reads, AI responses) must catch
  /// and handle this, not let it propagate as an uncaught type error.
  factory Pet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final species = json['species'];
    final breed = json['breed'];
    final age = json['age'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Pet.fromJson: missing or invalid "id"');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('Pet.fromJson: missing or invalid "name"');
    }
    if (species is! String || species.isEmpty) {
      throw const FormatException(
        'Pet.fromJson: missing or invalid "species"',
      );
    }

    return Pet(
      id: id,
      name: name,
      species: species,
      breed: breed is String ? breed : null,
      age: age is int ? age : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    if (breed != null) 'breed': breed,
    if (age != null) 'age': age,
  };

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    int? age,
  }) => Pet(
    id: id,
    name: name ?? this.name,
    species: species ?? this.species,
    breed: breed ?? this.breed,
    age: age ?? this.age,
  );

  @override
  bool operator ==(Object other) =>
      other is Pet &&
      other.id == id &&
      other.name == name &&
      other.species == species &&
      other.breed == breed &&
      other.age == age;

  @override
  int get hashCode => Object.hash(id, name, species, breed, age);
}
