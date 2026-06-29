# SLICE-D5: CSV import

status: pending
parallel_with: F1

## Prerequisites

D3

## Scope

- `packages/flowlog_core/lib/src/export/csv_import.dart`

## Done when

- [ ] Import exported CSV
- [ ] Round-trip identical shot in DB

## Verify

```bash
cd packages/flowlog_core && dart test test/csv_roundtrip_test.dart
```

## Fixture

fixtures/shots/minimal_shot.csv
