import 'package:meta/meta.dart';

import 'device_type.dart';

/// A paired BLE sensor (Pressensor or scale).
@immutable
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.lastConnectedAt,
  });

  final String id;
  final String name;
  final DeviceType type;
  final DateTime? lastConnectedAt;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.fromJson(json['type'] as String),
      lastConnectedAt: json['lastConnectedAt'] == null
          ? null
          : DateTime.parse(json['lastConnectedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toJson(),
      if (lastConnectedAt != null)
        'lastConnectedAt': lastConnectedAt!.toUtc().toIso8601String(),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DateTime? lastConnectedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Device &&
            id == other.id &&
            name == other.name &&
            type == other.type &&
            lastConnectedAt == other.lastConnectedAt;
  }

  @override
  int get hashCode => Object.hash(id, name, type, lastConnectedAt);

  @override
  String toString() =>
      'Device(id: $id, name: $name, type: $type, lastConnectedAt: $lastConnectedAt)';
}