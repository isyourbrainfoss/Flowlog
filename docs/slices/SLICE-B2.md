# SLICE-B2: MockReplayAdapter

status: done
parallel_with: B4, B5, B3

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/mock/`
- `fixtures/sensor_streams/demo_shot.jsonl`

## Done when

- [x] Replays jsonl fixture at configurable speed
- [x] Emits SensorSample stream
- [x] Unit test counts samples

## Verify

```bash
cd packages/flowlog_sensors && dart test
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
