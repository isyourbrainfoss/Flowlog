# SLICE-B5: PressensorBleAdapter

status: done
parallel_with: B2, B4, B3

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/pressensor/`
- `docs/protocols/pressensor-prs.md`

## Done when

- [x] Scan PRS* devices
- [x] Subscribe pressure notify, parse mbar
- [x] Zero pressure write
- [x] Mock-based unit tests pass

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=ble
```

## Fixture

docs/protocols/pressensor-prs.md
