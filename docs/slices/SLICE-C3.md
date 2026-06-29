# SLICE-C3: DualCurveChart live

status: pending
parallel_with: C1, C4, B7

## Prerequisites

B3, B2

## Scope

- `packages/flowlog_charts/lib/src/dual_curve_chart.dart`

## Done when

- [ ] Pressure + weight/flow curves
- [ ] Driven by mock stream in widget test
- [ ] Repaint boundary for performance

## Verify

```bash
cd packages/flowlog_charts && flutter test
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
