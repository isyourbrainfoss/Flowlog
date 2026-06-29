# SLICE-B5: PressensorBleAdapter

status: pending
parallel_with: B2, B4, B3

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/pressensor/`
- `docs/protocols/pressensor-prs.md`

## Done when

- [ ] Scan PRS* devices
- [ ] Subscribe pressure notify, parse mbar
- [ ] Zero pressure write
- [ ] Mock-based unit tests pass

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=ble
```

## Fixture

docs/protocols/pressensor-prs.md
