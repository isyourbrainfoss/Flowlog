# SLICE-B3: Flow rate derivation

status: pending
parallel_with: B2, B4, B5

## Prerequisites

A3

## Scope

- `packages/flowlog_core/lib/src/flow_rate.dart`

## Done when

- [ ] weightG series to smoothed flowGs
- [ ] Unit tests match golden values
- [ ] Handles gaps in samples

## Verify

```bash
cd packages/flowlog_core && dart test test/flow_rate_test.dart
```

## Fixture

fixtures/sensor_streams/flow_rate_golden.json
