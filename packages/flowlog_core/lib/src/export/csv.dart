import '../models/shot.dart';
import '../models/shot_sample.dart';

/// Exports a [Shot] to a deterministic CSV document.
///
/// The format uses a metadata section (`key,value` rows) followed by a blank
/// line and a time-series section with columns
/// `elapsed_ms,pressure_bar,weight_g,flow_gs,temp_c`.
String exportShotToCsv(Shot shot) {
  final buffer = StringBuffer();

  buffer.writeln('key,value');
  buffer.writeln('export_version,1');
  buffer.writeln('id,${_csvCell(shot.id)}');
  buffer.writeln('started_at,${_csvCell(shot.startedAt.toUtc().toIso8601String())}');

  if (shot.endedAt != null) {
    buffer.writeln(
      'ended_at,${_csvCell(shot.endedAt!.toUtc().toIso8601String())}',
    );
  }
  if (shot.doseG != null) {
    buffer.writeln('dose_g,${_formatDouble(shot.doseG!)}');
  }
  if (shot.yieldG != null) {
    buffer.writeln('yield_g,${_formatDouble(shot.yieldG!)}');
  }
  if (shot.grindSetting != null) {
    buffer.writeln('grind_setting,${_formatDouble(shot.grindSetting!)}');
  }
  if (shot.beanId != null) {
    buffer.writeln('bean_id,${_csvCell(shot.beanId!)}');
  }
  if (shot.waterTempC != null) {
    buffer.writeln('water_temp_c,${_formatDouble(shot.waterTempC!)}');
  }
  if (shot.notes != null) {
    buffer.writeln('notes,${_csvCell(shot.notes!)}');
  }
  if (shot.tasteScore != null) {
    buffer.writeln('taste_score,${shot.tasteScore}');
  }
  if (shot.flavourTags.isNotEmpty) {
    buffer.writeln(
      'flavour_tags,${_csvCell(shot.flavourTags.join(';'))}',
    );
  }

  buffer.writeln();
  buffer.writeln('elapsed_ms,pressure_bar,weight_g,flow_gs,temp_c');

  final samples = List<ShotSample>.from(shot.samples)
    ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));

  for (final sample in samples) {
    buffer.writeln([
      sample.elapsedMs,
      _formatNullableDouble(sample.pressureBar),
      _formatNullableDouble(sample.weightG),
      _formatNullableDouble(sample.flowGs),
      _formatNullableDouble(sample.tempC),
    ].join(','));
  }

  return buffer.toString();
}

String _formatDouble(double value) => value.toString();

String _formatNullableDouble(double? value) =>
    value == null ? '' : _formatDouble(value);

String _csvCell(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}