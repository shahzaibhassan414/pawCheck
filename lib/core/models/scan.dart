import 'urgency_level.dart';

class Scan {
  const Scan({
    required this.id,
    required this.photoUrl,
    required this.timestamp,
    required this.aiDescription,
    required this.urgencyLevel,
    this.note,
    this.aiCauses = const [],
    this.resolved = false,
  });

  final String id;
  final String photoUrl;
  final String? note;
  final DateTime timestamp;
  final String aiDescription;
  final List<String> aiCauses;
  final UrgencyLevel urgencyLevel;
  final bool resolved;

  bool get showsFindVetCta => urgencyLevel.showsFindVetCta;

  /// Throws [FormatException] on missing/invalid required fields rather
  /// than crashing — callers (Firestore reads, AI responses) must catch
  /// and handle this, not let it propagate as an uncaught type error.
  factory Scan.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final photoUrl = json['photoUrl'];
    final timestampRaw = json['timestamp'];
    final aiDescription = json['aiDescription'];
    final urgencyRaw = json['urgencyLevel'];
    final note = json['note'];
    final aiCausesRaw = json['aiCauses'];
    final resolved = json['resolved'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Scan.fromJson: missing or invalid "id"');
    }
    if (photoUrl is! String || photoUrl.isEmpty) {
      throw const FormatException(
        'Scan.fromJson: missing or invalid "photoUrl"',
      );
    }
    if (aiDescription is! String || aiDescription.isEmpty) {
      throw const FormatException(
        'Scan.fromJson: missing or invalid "aiDescription"',
      );
    }

    final timestamp = switch (timestampRaw) {
      String s => DateTime.tryParse(s),
      _ => null,
    };
    if (timestamp == null) {
      throw const FormatException(
        'Scan.fromJson: missing or invalid "timestamp"',
      );
    }

    if (urgencyRaw is! String) {
      throw const FormatException(
        'Scan.fromJson: missing or invalid "urgencyLevel"',
      );
    }
    final urgencyLevel = UrgencyLevel.parse(urgencyRaw);

    return Scan(
      id: id,
      photoUrl: photoUrl,
      timestamp: timestamp,
      aiDescription: aiDescription,
      urgencyLevel: urgencyLevel,
      note: note is String ? note : null,
      aiCauses: aiCausesRaw is List
          ? aiCausesRaw.whereType<String>().toList()
          : const [],
      resolved: resolved is bool ? resolved : false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'photoUrl': photoUrl,
    'timestamp': timestamp.toIso8601String(),
    'aiDescription': aiDescription,
    'aiCauses': aiCauses,
    'urgencyLevel': urgencyLevel.wireValue,
    'resolved': resolved,
    if (note != null) 'note': note,
  };

  Scan copyWith({bool? resolved}) => Scan(
    id: id,
    photoUrl: photoUrl,
    timestamp: timestamp,
    aiDescription: aiDescription,
    urgencyLevel: urgencyLevel,
    note: note,
    aiCauses: aiCauses,
    resolved: resolved ?? this.resolved,
  );

  @override
  bool operator ==(Object other) =>
      other is Scan &&
      other.id == id &&
      other.photoUrl == photoUrl &&
      other.note == note &&
      other.timestamp == timestamp &&
      other.aiDescription == aiDescription &&
      _listEquals(other.aiCauses, aiCauses) &&
      other.urgencyLevel == urgencyLevel &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(
    id,
    photoUrl,
    note,
    timestamp,
    aiDescription,
    Object.hashAll(aiCauses),
    urgencyLevel,
    resolved,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
