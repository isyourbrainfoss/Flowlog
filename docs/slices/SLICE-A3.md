# SLICE-A3: flowlog_core models

status: done
parallel_with: A2, A5

## Prerequisites

A1

## Scope

- `packages/flowlog_core/lib/src/models/`
- `packages/flowlog_core/test/models_test.dart`

## Done when

- [x] Shot, ShotSample, Bean, Device types defined
- [x] toJson/fromJson round-trip tests pass
- [x] Exported from flowlog_core.dart

## Verify

```bash
cd packages/flowlog_core && dart test
```

## Fixture

fixtures/shots/minimal_shot.json (added in slice)