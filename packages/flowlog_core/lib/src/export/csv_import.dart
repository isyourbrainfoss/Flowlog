import 'dart:convert';

import '../models/flavour_intensities.dart';
import '../models/shot.dart';
import '../models/shot_sample.dart';

/// Parses a Flowlog shot CSV document produced by [exportShotToCsv].
///
/// The format uses a metadata section (`key,value` rows) followed by a blank
/// line and a time-series section with columns
/// `elapsed_ms,pressure_bar,weight_g,flow_gs,temp_c`.
Shot importShotFromCsv(String csv) {
  final metadata = <String, String>{};
  final samples = <ShotSample>[];
  var section = _CsvSection.metadata;
  var sawMetadataHeader = false;
  var sawSamplesHeader = false;

  for (final rawLine in const LineSplitter().convert(csv)) {
    final line = rawLine.trimRight();

    if (line.isEmpty) {
      if (section == _CsvSection.metadata && sawMetadataHeader) {
        section = _CsvSection.samples;
      }
      continue;
    }

    final fields = _parseCsvRow(line);
    if (fields.isEmpty) {
      continue;
    }

    switch (section) {
      case _CsvSection.metadata:
        if (!sawMetadataHeader) {
          if (fields.length != 2 || fields[0] != 'key' || fields[1] != 'value') {
            throw const FormatException('CSV metadata must start with key,value');
          }
          sawMetadataHeader = true;
          continue;
        }

        if (fields.length != 2) {
          throw FormatException('Invalid metadata row: $line');
        }

        metadata[fields[0]] = fields[1];
      case _CsvSection.samples:
        if (!sawSamplesHeader) {
          if (!_isSamplesHeader(fields)) {
            throw FormatException('Expected samples header, got: $line');
          }
          sawSamplesHeader = true;
          continue;
        }

        if (fields.length != 5) {
          throw FormatException('Invalid sample row: $line');
        }

        samples.add(
          ShotSample(
            elapsedMs: _parseInt(fields[0], fieldName: 'elapsed_ms'),
            pressureBar: _parseNullableDouble(fields[1]),
            weightG: _parseNullableDouble(fields[2]),
            flowGs: _parseNullableDouble(fields[3]),
            tempC: _parseNullableDouble(fields[4]),
          ),
        );
    }
  }

  if (!sawMetadataHeader) {
    throw const FormatException('CSV metadata section is missing');
  }
  if (!sawSamplesHeader) {
    throw const FormatException('CSV samples section is missing');
  }

  final exportVersion = metadata['export_version'];
  if (exportVersion != '1') {
    throw FormatException('Unsupported export_version: $exportVersion');
  }

  final id = metadata['id'];
  if (id == null || id.isEmpty) {
    throw const FormatException('CSV metadata is missing required id');
  }

  final startedAtRaw = metadata['started_at'];
  if (startedAtRaw == null || startedAtRaw.isEmpty) {
    throw const FormatException('CSV metadata is missing required started_at');
  }

  final unknownKeys = metadata.keys
      .where((key) => !_knownMetadataKeys.contains(key))
      .toList();
  if (unknownKeys.isNotEmpty) {
    throw FormatException('Unknown metadata keys: ${unknownKeys.join(', ')}');
  }

  final endedAtRaw = metadata['ended_at'];

  return Shot(
    id: id,
    startedAt: DateTime.parse(startedAtRaw),
    endedAt: endedAtRaw == null || endedAtRaw.isEmpty
        ? null
        : DateTime.parse(endedAtRaw),
    doseG: _parseNullableDouble(metadata['dose_g']),
    yieldG: _parseNullableDouble(metadata['yield_g']),
    grindSetting: _parseNullableDouble(metadata['grind_setting']),
    beanId: _nullableString(metadata['bean_id']),
    waterTempC: _parseNullableDouble(metadata['water_temp_c']),
    notes: _nullableString(metadata['notes']),
    tasteScore: _parseNullableInt(metadata['taste_score']),
    flavourTags: _parseFlavourTags(metadata['flavour_tags']),
    flavourIntensities: parseFlavourIntensitiesCsv(
      metadata['flavour_intensities'],
    ),
    samples: samples,
  );
}

enum _CsvSection { metadata, samples }

const _knownMetadataKeys = {
  'export_version',
  'id',
  'started_at',
  'ended_at',
  'dose_g',
  'yield_g',
  'grind_setting',
  'bean_id',
  'water_temp_c',
  'notes',
  'taste_score',
  'flavour_tags',
  'flavour_intensities',
};

bool _isSamplesHeader(List<String> fields) {
  return fields.length == 5 &&
      fields[0] == 'elapsed_ms' &&
      fields[1] == 'pressure_bar' &&
      fields[2] == 'weight_g' &&
      fields[3] == 'flow_gs' &&
      fields[4] == 'temp_c';
}

List<String> _parseCsvRow(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  if (inQuotes) {
    throw FormatException('Unterminated quoted CSV field: $line');
  }

  fields.add(buffer.toString());
  return fields;
}

double? _parseNullableDouble(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return double.parse(raw);
}

int? _parseNullableInt(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return int.parse(raw);
}

int _parseInt(String raw, {required String fieldName}) {
  if (raw.isEmpty) {
    throw FormatException('Missing required integer field: $fieldName');
  }
  return int.parse(raw);
}

String? _nullableString(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

List<String> _parseFlavourTags(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  return raw.split(';');
}