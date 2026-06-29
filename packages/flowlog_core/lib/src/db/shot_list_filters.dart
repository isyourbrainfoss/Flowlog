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

  bool get isActive =>
      beanQuery.trim().isNotEmpty ||
      startedOnOrAfter != null ||
      startedOnOrBefore != null ||
      minTasteScore != null ||
      minPeakPressureBar != null;

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
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotListFilters &&
            beanQuery == other.beanQuery &&
            startedOnOrAfter == other.startedOnOrAfter &&
            startedOnOrBefore == other.startedOnOrBefore &&
            minTasteScore == other.minTasteScore &&
            minPeakPressureBar == other.minPeakPressureBar;
  }

  @override
  int get hashCode => Object.hash(
        beanQuery,
        startedOnOrAfter,
        startedOnOrBefore,
        minTasteScore,
        minPeakPressureBar,
      );
}