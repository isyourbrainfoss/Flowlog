import 'package:drift/drift.dart';

/// Stores UTC [DateTime] values as ISO-8601 text to preserve millisecond precision.
class UtcIso8601Converter extends TypeConverter<DateTime, String> {
  const UtcIso8601Converter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb).toUtc();

  @override
  String toSql(DateTime value) => value.toUtc().toIso8601String();
}

/// Nullable variant of [UtcIso8601Converter].
class NullableUtcIso8601Converter extends TypeConverter<DateTime?, String?> {
  const NullableUtcIso8601Converter();

  @override
  DateTime? fromSql(String? fromDb) {
    if (fromDb == null) {
      return null;
    }
    return DateTime.parse(fromDb).toUtc();
  }

  @override
  String? toSql(DateTime? value) => value?.toUtc().toIso8601String();
}