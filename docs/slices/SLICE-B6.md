# SLICE-B6: MergedSampleStream

status: pending
parallel_with: C1

## Prerequisites

B4, B5

## Scope

- `packages/flowlog_sensors/lib/src/merged_stream.dart`

## Done when

- [ ] Merges pressure + weight on host monotonic clock
- [ ] Works with only one sensor connected
- [ ] Unit test with two mock adapters

## Verify

```bash
cd packages/flowlog_sensors && dart test test/merged_stream_test.dart
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
