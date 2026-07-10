# flowlog_sensors

Sensor adapters, stream merging, and mock replay for Flowlog.

Provides the `SensorAdapter` abstraction and `MergedSampleStream` used to feed `ShotSession` from pressure sensors, scales, or fixtures. Includes concrete adapters for Pressensor and WiFi/Decent scales (via injected transports).

## Features

- `SensorAdapter` abstract interface (state + samples streams, connect/disconnect).
- `MergedSampleStream` unifies one pressure + one weight adapter onto shared timeline with last-value carry-forward.
- `MockReplayAdapter` for replaying JSONL fixtures (real-time or accelerated, path or loader).
- Pressensor PRS protocol parser + BLE adapter.
- WiFi scale and Decent scale support (adapters + low-level).
- `SensorSample` with easy conversion to core `ShotSample`.

## Getting started

```yaml
dependencies:
  flowlog_sensors:
```

Depends on `flowlog_core`. No direct dependency on `flutter_blue_plus` — the app layer wires platform BLE transports into the adapter constructors.


## Usage

```dart
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_core/flowlog_core.dart';

// Mock for tests / demos
final adapter = MockReplayAdapter(
  fixturePath: 'fixtures/sensor_streams/demo_shot.jsonl',
  speed: 1.0,
);
await adapter.connect();

// Or real (transports supplied by app)
final pressure = PressensorBleAdapter(transport: myTransport);
final weight = ...;
final merged = MergedSampleStream(
  pressureAdapter: pressure,
  weightAdapter: weight,
);
await merged.start();
final streamForSession = merged.samples.map((s) => s.toShotSample());

// Feed to core
final session = ShotSession();
session.start(streamForSession);
```

See `example/` and `app/flowlog/lib/sensors/` for hub + wrapper patterns.

Use `MockReplayAdapter` (and `fixtureLoader` for Flutter assets) in tests. Real adapters often have `manageAdapterLifecycle: false` when a central hub manages connect/disconnect.


## Additional information

See the root project [README](../../README.md) and [docs/PLAN.md](../../docs/PLAN.md).

**Important:** Use mocks for tests. BLE details are in `docs/protocols/`.

