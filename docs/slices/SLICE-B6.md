# SLICE-B6: MergedSampleStream

status: done
parallel_with: C1

## Prerequisites

B4, B5

## Scope

- `packages/flowlog_sensors/lib/src/merged_stream.dart`

## Done when

- [x] Merges pressure + weight on host monotonic clock
- [x] Works with only one sensor connected
- [x] Unit test with two mock adapters

## Verify

```bash
cd packages/flowlog_sensors && dart test test/merged_stream_test.dart
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
