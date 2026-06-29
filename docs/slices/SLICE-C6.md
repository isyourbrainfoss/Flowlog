# SLICE-C6: Save shot + God Shot FAB

status: pending
parallel_with: C8, D1

## Prerequisites

C2, C5

## Scope

- `app/flowlog/lib/screens/live/save_shot.dart`

## Done when

- [ ] Persist samples + metadata to DB
- [ ] God Shot FAB visible on Live
- [ ] Success snackbar

## Verify

```bash
cd packages/flowlog_core && dart test && cd ../../app/flowlog && flutter test
```

## Fixture

fixtures/shots/minimal_shot.json
