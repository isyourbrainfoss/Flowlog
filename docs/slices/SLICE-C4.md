# SLICE-C4: Floating metrics row

status: done
parallel_with: C5, C2

## Prerequisites

C3

## Scope

- `app/flowlog/lib/screens/live/metrics_row.dart`

## Done when

- [x] Shows pressure, flow, elapsed, projected yield
- [x] Trend arrows on change

## Verify

```bash
cd app/flowlog && flutter test
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
