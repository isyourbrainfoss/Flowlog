# flowlog_charts

Flutter chart widgets (CustomPainter) for live and historical espresso shot curves in Flowlog.

`DualCurveChart` renders pressure, weight, and flow with interaction, annotations, and target overlays. Includes `SparklineChart` for compact previews. Depends on `flowlog_core` `ShotSample`.

## Features

- `DualCurveChart`: live/static rendering of shot curves (overlay, split, flow-only), ValueNotifier support, pinch/pan/zoom, annotations, target pressure curve, crosshair.
- `SparklineChart`: compact pressure history sparkline.
- Theming via `FlowlogChartColors` (coffee palette + colorblind-safe option).
- `ChartInteractionController`, `ChartViewport`, `ChartViewMode` for external control and state.
- Annotation painting helpers.

## Getting started

```yaml
dependencies:
  flowlog_charts:
    # (or via workspace)
```

This is a Flutter package (requires Flutter SDK). Depends on `flowlog_core` for `ShotSample` / `ShotAnnotation`.


## Usage

```dart
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

final samplesNotifier = ValueNotifier<List<ShotSample>>([]);

// Live chart wired to a session
DualCurveChart(
  samplesNotifier: samplesNotifier,
  annotationsNotifier: annotationsNotifier,
  interactionController: _controller,
  height: 220,
  denseTimeAxis: true,
  onAnnotateAtElapsedMs: onAnnotate,
  targetPressureSamples: targetSamples,
);

// Static history view
DualCurveChart(
  samples: shot.samples,
  annotations: shot.annotations,
  enableInteraction: false,
);

// Compact
SparklineChart(samples: shot.samples, height: 48);
```

See `app/flowlog/lib/screens/live_screen.dart`, `shot_detail.dart`, and `packages/flowlog_charts/test/` for more patterns.

Use `samples` for static data or `samplesNotifier` for live updates from `ShotSession.sampleBatches`.


## Additional information

See the root project [README](../../README.md) for context. The charts are used throughout the live view and history screens.

