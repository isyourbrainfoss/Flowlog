import 'package:meta/meta.dart';

/// User-defined label for organizing shots.
@immutable
class Tag {
  const Tag({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  Tag copyWith({
    String? id,
    String? name,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Tag && id == other.id && name == other.name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Tag(id: $id, name: $name)';
}

/// Links a shot to an organizational tag for sync export/import.
@immutable
class ShotTagLink {
  const ShotTagLink({
    required this.shotId,
    required this.tagId,
  });

  final String shotId;
  final String tagId;

  factory ShotTagLink.fromJson(Map<String, dynamic> json) {
    return ShotTagLink(
      shotId: json['shotId'] as String,
      tagId: json['tagId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shotId': shotId,
      'tagId': tagId,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotTagLink &&
            shotId == other.shotId &&
            tagId == other.tagId;
  }

  @override
  int get hashCode => Object.hash(shotId, tagId);
}