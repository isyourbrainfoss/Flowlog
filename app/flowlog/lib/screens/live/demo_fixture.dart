import 'dart:io';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/services.dart';

/// Asset path of the bundled demo shot replayed by "Try demo shot".
const String kBundledDemoFixtureAsset = 'assets/demo_shot.jsonl';

/// Finds the repo demo fixture on disk (desktop dev / tests), if present.
///
/// Returns null in release builds, where [loadBundledDemoFixture] is used.
String? resolveDemoFixtureFilePath() {
  const candidates = [
    '../../fixtures/sensor_streams/demo_shot.jsonl',
    '../../../fixtures/sensor_streams/demo_shot.jsonl',
    'fixtures/sensor_streams/demo_shot.jsonl',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return file.path;
    }
  }

  return null;
}

/// Loads and parses the demo shot bundled as [kBundledDemoFixtureAsset].
Future<List<SensorSample>> loadBundledDemoFixture() async {
  final content = await rootBundle.loadString(kBundledDemoFixtureAsset);
  return MockReplayAdapter.parseLines(
    content.split('\n'),
    source: kBundledDemoFixtureAsset,
  );
}
