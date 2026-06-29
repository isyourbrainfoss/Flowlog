# SLICE-B4: DecentScaleBleAdapter

status: done
parallel_with: B2, B5, B3

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/decent_scale/`
- `docs/protocols/decent-scale-ble.md`

## Done when

- [x] LED on, tare, FFF4 parse
- [x] Heartbeat timer for HDS
- [x] Mock-based unit tests pass
- [x] Optional @Tags(['ble']) integration test

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=ble
```

## Fixture

docs/protocols/decent-scale-ble.md
