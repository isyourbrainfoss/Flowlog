import 'package:meta/meta.dart';

/// Kind of marker placed on a shot curve.
enum ShotAnnotationType {
  /// Marks a channel switch (e.g. pre-infusion to main pump).
  channel,

  /// Free-form note at a point in time.
  note,
}

/// A time-stamped label on a shot chart.
@immutable
class ShotAnnotation {
  const ShotAnnotation({
    required this.elapsedMs,
    required this.label,
    required this.type,
  });

  final int elapsedMs;
  final String label;
  final ShotAnnotationType type;

  factory ShotAnnotation.fromJson(Map<String, dynamic> json) {
    return ShotAnnotation(
      elapsedMs: json['elapsedMs'] as int,
      label: json['label'] as String,
      type: _typeFromJson(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'elapsedMs': elapsedMs,
      'label': label,
      'type': _typeToJson(type),
    };
  }

  ShotAnnotation copyWith({
    int? elapsedMs,
    String? label,
    ShotAnnotationType? type,
  }) {
    return ShotAnnotation(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      label: label ?? this.label,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotAnnotation &&
            elapsedMs == other.elapsedMs &&
            label == other.label &&
            type == other.type;
  }

  @override
  int get hashCode => Object.hash(elapsedMs, label, type);

  @override
  String toString() =>
      'ShotAnnotation(elapsedMs: $elapsedMs, label: $label, type: $type)';
}

ShotAnnotationType _typeFromJson(String value) {
  return switch (value) {
    'channel' => ShotAnnotationType.channel,
    'note' => ShotAnnotationType.note,
    _ => throw ArgumentError.value(value, 'type', 'Unknown annotation type'),
  };
}

String _typeToJson(ShotAnnotationType type) {
  return switch (type) {
    ShotAnnotationType.channel => 'channel',
    ShotAnnotationType.note => 'note',
  };
}

/// Helpers for building annotation lists during a live session.
abstract final class ShotAnnotationHelpers {
  /// Creates the next channel mark label for [existing] annotations.
  static String nextChannelLabel(List<ShotAnnotation> existing) {
    final channelCount = existing
        .where((annotation) => annotation.type == ShotAnnotationType.channel)
        .length;
    return 'Channel ${channelCount + 1}';
  }

  /// Appends [annotation] to [existing].
  static List<ShotAnnotation> add(
    List<ShotAnnotation> existing,
    ShotAnnotation annotation,
  ) {
    return [...existing, annotation];
  }

  /// Removes the most recently added annotation, if any.
  static List<ShotAnnotation> undo(List<ShotAnnotation> existing) {
    if (existing.isEmpty) {
      return existing;
    }
    return existing.sublist(0, existing.length - 1);
  }

  /// Builds a channel annotation at [elapsedMs].
  static ShotAnnotation channelMark(
    List<ShotAnnotation> existing, {
    required int elapsedMs,
  }) {
    return ShotAnnotation(
      elapsedMs: elapsedMs,
      label: nextChannelLabel(existing),
      type: ShotAnnotationType.channel,
    );
  }

  /// Builds a note annotation at [elapsedMs].
  static ShotAnnotation note({
    required int elapsedMs,
    required String label,
  }) {
    return ShotAnnotation(
      elapsedMs: elapsedMs,
      label: label,
      type: ShotAnnotationType.note,
    );
  }
}