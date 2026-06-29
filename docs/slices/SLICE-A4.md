# SLICE-A4: SQLite schema + migrations

status: pending
parallel_with: A5, A6

## Prerequisites

A3

## Scope

- `packages/flowlog_core/lib/src/db/`
- `packages/flowlog_core/test/db_test.dart`

## Done when

- [ ] drift (or sqlite) schema for shots + samples
- [ ] Insert and read shot with samples
- [ ] Migration from v1 works

## Verify

```bash
cd packages/flowlog_core && dart test test/db_test.dart
```

## Fixture

fixtures/shots/minimal_shot.json
