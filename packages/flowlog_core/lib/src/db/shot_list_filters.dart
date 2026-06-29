import 'package:meta/meta.dart';

/// Criteria for narrowing [ShotRepository.listShots] results.
@immutable
class ShotListFilters {
  const ShotListFilters({
    this.beanQuery = '',
    this.startedOnOrAfter,
    this.startedOnOrBefore,
    this.minTasteScore,
    this.minPeakPressureBar,
    this.tagIds = const {},
  });

  static const empty = ShotListFilters();

  /// Case-insensitive substring matched against bean id and linked bean name.
  final String beanQuery;

  /// Inclusive lower bound on [Shot.startedAt].
  final DateTime? startedOnOrAfter;

  /// Inclusive upper bound on [Shot.startedAt].
  final DateTime? startedOnOrBefore;

  /// Minimum taste score (0–10); shots without a score are excluded.
  final int? minTasteScore;

  /// Minimum peak sample pressure in bar; shots without samples are excluded.
  final double? minPeakPressureBar;

  /// When non-empty, keeps shots linked to any selected tag id.
  final Set<String> tagIds;

  bool get isActive =>
      beanQuery.trim().isNotEmpty ||
      startedOnOrAfter != null ||
      startedOnOrBefore != null ||
      minTasteScore != null ||
      minPeakPressureBar != null ||
      tagIds.isNotEmpty;

  ShotListFilters copyWith({
    String? beanQuery,
    DateTime? startedOnOrAfter,
    bool clearStartedOnOrAfter = false,
    DateTime? startedOnOrBefore,
    bool clearStartedOnOrBefore = false,
    int? minTasteScore,
    bool clearMinTasteScore = false,
    double? minPeakPressureBar,
    bool clearMinPeakPressureBar = false,
    Set<String>? tagIds,
    bool clearTagIds = false,
  }) {
    return ShotListFilters(
      beanQuery: beanQuery ?? this.beanQuery,
      startedOnOrAfter: clearStartedOnOrAfter
          ? null
          : (startedOnOrAfter ?? this.startedOnOrAfter),
      startedOnOrBefore: clearStartedOnOrBefore
          ? null
          : (startedOnOrBefore ?? this.startedOnOrBefore),
      minTasteScore:
          clearMinTasteScore ? null : (minTasteScore ?? this.minTasteScore),
      minPeakPressureBar: clearMinPeakPressureBar
          ? null
          : (minPeakPressureBar ?? this.minPeakPressureBar),
      tagIds: clearTagIds ? const {} : (tagIds ?? this.tagIds),
    );
  }

  /// Toggles [tagId] in [tagIds].
  ShotListFilters toggleTagId(String tagId) {
    final next = Set<String>.from(tagIds);
    if (next.contains(tagId)) {
      next.remove(tagId);
    } else {
      next.add(tagId);
    }
    return copyWith(tagIds: next);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotListFilters &&
            beanQuery == other.beanQuery &&
            startedOnOrAfter == other.startedOnOrAfter &&
            startedOnOrBefore == other.startedOnOrBefore &&
            minTasteScore == other.minTasteScore &&
            minPeakPressureBar == other.minPeakPressureBar &&
            _setEquals(tagIds, other.tagIds);
  }

  @override
  int get hashCode => Object.hash(
        beanQuery,
        startedOnOrAfter,
        startedOnOrBefore,
        minTasteScore,
        minPeakPressureBar,
        Object.hashAllUnordered(tagIds),
      );
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}