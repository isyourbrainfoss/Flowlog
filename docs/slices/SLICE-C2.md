# SLICE-C2: Start/Stop + auto-tare

status: pending
parallel_with: C4, C5

## Prerequisites

C1

## Scope

- `app/flowlog/lib/screens/live/controls.dart`

## Done when

- [ ] Start begins recording via ShotSession
- [ ] Stop finalizes session
- [ ] Start sends tare to mock/scale adapter

## Verify

```bash
cd app/flowlog && flutter test
```

## Fixture

none
