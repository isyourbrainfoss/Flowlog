# SLICE-E1: Chart zoom/pan + view modes

status: done
parallel_with: E2, E6

## Prerequisites

C3

## Scope

- `packages/flowlog_charts/lib/src/chart_interaction.dart`

## Done when

- [x] Pinch/zoom and pan
- [x] Swipe overlay/split/flow-only modes

## Verify

```bash
cd packages/flowlog_charts && flutter test
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
