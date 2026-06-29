# SLICE-A4: SQLite schema + migrations

status: done
parallel_with: A5, A6

## Prerequisites

A3

## Scope

- `packages/flowlog_core/lib/src/db/`
- `packages/flowlog_core/test/db_test.dart`

## Done when

- [x] drift (or sqlite) schema for shots + samples
- [x] Insert and read shot with samples
- [x] Migration from v1 works

## Verify

```bash
cd packages/flowlog_core && dart test test/db_test.dart
```

## Fixture

fixtures/shots/minimal_shot.json
