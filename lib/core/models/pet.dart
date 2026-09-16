class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.age,
    this.photoUrl,
    this.gender,
  });

  final String id;
  final String name;
  final String species;
  final String? breed;
  final int? age;

  /// A `data:image/jpeg;base64,...` URI, same convention as
  /// `Scan.photoUrl` (no Firebase Storage — see that field's context for
  /// why). Optional, unlike `Scan.photoUrl` — a pet photo is a nice-to-have
  /// picked during setup, not a required part of a scan.
  final String? photoUrl;

  /// `'Male'` or `'Female'` — optional, same loose-String convention as
  /// [species] rather than an enum (species already established this
  /// pattern for a small fixed set of values).
  final String? gender;

  /// Throws [FormatException] on missing/invalid required fields rather
  /// than crashing — callers (Firestore reads, AI responses) must catch
  /// and handle this, not let it propagate as an uncaught type error.
  factory Pet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final species = json['species'];
    final breed = json['breed'];
    final age = json['age'];
    final photoUrl = json['photoUrl'];
    final gender = json['gender'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Pet.fromJson: missing or invalid "id"');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('Pet.fromJson: missing or invalid "name"');
    }
    if (species is! String || species.isEmpty) {
      throw const FormatException('Pet.fromJson: missing or invalid "species"');
    }

    return Pet(
      id: id,
      name: name,
      species: species,
      breed: breed is String ? breed : null,
      age: age is int ? age : null,
      photoUrl: photoUrl is String ? photoUrl : null,
      gender: gender is String ? gender : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    if (breed != null) 'breed': breed,
    if (age != null) 'age': age,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (gender != null) 'gender': gender,
  };

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    int? age,
    String? photoUrl,
    String? gender,
  }) => Pet(
    id: id,
    name: name ?? this.name,
    species: species ?? this.species,
    breed: breed ?? this.breed,
    age: age ?? this.age,
    photoUrl: photoUrl ?? this.photoUrl,
    gender: gender ?? this.gender,
  );

  @override
  bool operator ==(Object other) =>
      other is Pet &&
      other.id == id &&
      other.name == name &&
      other.species == species &&
      other.breed == breed &&
      other.age == age &&
      other.photoUrl == photoUrl &&
      other.gender == gender;

  @override
  int get hashCode =>
      Object.hash(id, name, species, breed, age, photoUrl, gender);
}
