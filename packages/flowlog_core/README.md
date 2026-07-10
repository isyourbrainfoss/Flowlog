# flowlog_core

Core models, persistence (Drift), shot session logic, CSV/PDF export, and sync for the Flowlog coffee shot tracker.

Intended for the Flowlog app and Dart code handling espresso shot models and storage.

## Features

- Data models (`Shot`, `ShotSample`, `Bean`, `SavedProfile`, annotations, tags, etc.).
- `ShotSession` state machine to record from `Stream<ShotSample>` or manually (start/pause/resume/stop).
- Drift-backed `FlowlogDatabase` and `*Repository` classes for persistence.
- `FlowRateCalculator` and `ShotDetector` for derived metrics and auto-detection.
- CSV export/import and PDF export for shots.
- Sync helpers (blobs, Nextcloud).

## Getting started

Add to your `pubspec.yaml` (in this workspace it resolves automatically):

```yaml
dependencies:
  flowlog_core:
```

The package requires a Dart SDK ^3.12.2 and pulls in `drift` for DB.

## Usage

```dart
import 'package:flowlog_core/flowlog_core.dart';

// Shot session (live recording)
final session = ShotSession();
session.start(sensorStream);  // Stream<ShotSample>
session.pause();
session.resume();
await session.stop();
await session.dispose();

// Database + repo
final db = FlowlogDatabase.inMemory(); // or .openFile(path)
final repo = ShotRepository(db);
await repo.insertShot(shot);
final history = await repo.listShots(includeSamples: true);

// Processing
final withFlow = computeFlowRates(samples);
final detection = detectShotStart(samples);
```

See `example/flowlog_core_example.dart` and tests for more. Production usage is in `app/flowlog/`.


## Additional information

See the root project [README](../../README.md) for installation, development, and architecture notes.

Report issues and contribute in the main Flowlog repository. This package is not published to pub.dev.

