# SLICE-C7: Auto shot detect

status: pending
parallel_with: C8

## Prerequisites

C1, B3

## Scope

- `packages/flowlog_core/lib/src/shot_detect.dart`

## Done when

- [ ] First flow > threshold sets t=0
- [ ] Configurable threshold in settings stub
- [ ] Unit tested

## Verify

```bash
cd packages/flowlog_core && dart test test/shot_detect_test.dart
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
