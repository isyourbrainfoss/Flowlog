# SLICE-C2: Start/Stop + auto-tare

status: done
parallel_with: C4, C5

## Prerequisites

C1

## Scope

- `app/flowlog/lib/screens/live/controls.dart`

## Done when

- [x] Start begins recording via ShotSession
- [x] Stop finalizes session
- [x] Start sends tare to mock/scale adapter

## Verify

```bash
cd app/flowlog && flutter test
```

## Fixture

none
