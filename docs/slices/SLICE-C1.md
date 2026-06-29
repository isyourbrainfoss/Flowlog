# SLICE-C1: ShotSession state machine

status: pending
parallel_with: C3, B6, B7

## Prerequisites

A4, B2

## Scope

- `packages/flowlog_core/lib/src/shot_session.dart`

## Done when

- [ ] States: idle, recording, paused, stopped
- [ ] Emits sample batches to listeners
- [ ] Unit tests cover transitions

## Verify

```bash
cd packages/flowlog_core && dart test test/shot_session_test.dart
```

## Fixture

fixtures/sensor_streams/demo_shot.jsonl
