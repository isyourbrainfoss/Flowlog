# SLICE-F7: PDF export

status: done
parallel_with: F3

## Prerequisites

D2

## Scope

- `packages/flowlog_core/lib/src/export/pdf.dart`

## Done when

- [x] Single shot PDF report
- [x] Unit test output structure

## Verify

```bash
cd packages/flowlog_core && dart test test/pdf_export_test.dart
```

## Fixture

fixtures/shots/minimal_shot.json
