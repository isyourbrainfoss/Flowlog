# SLICE-D3: CSV export single shot

status: pending
parallel_with: D1, D4

## Prerequisites

C6

## Scope

- `packages/flowlog_core/lib/src/export/csv.dart`

## Done when

- [ ] Export matches golden CSV byte-for-byte
- [ ] Unit test

## Verify

```bash
cd packages/flowlog_core && dart test test/csv_export_test.dart
```

## Fixture

fixtures/shots/minimal_shot.csv
