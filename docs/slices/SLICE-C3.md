# SLICE-C3: DualCurveChart live

status: done
parallel_with: C1, C4, B7

## Prerequisites

B3, B2

## Scope

- `packages/flowlog_charts/lib/src/dual_curve_chart.dart`

## Done when

- [x] Pressure + weight/flow curves
- [x] Driven by mock stream in widget test
- [x] Repaint boundary for performance

## Verify

```bash
cd packages/flowlog_charts && flutter test
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
