# SLICE-B4: DecentScaleBleAdapter

status: pending
parallel_with: B2, B5, B3

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/decent_scale/`
- `docs/protocols/decent-scale-ble.md`

## Done when

- [ ] LED on, tare, FFF4 parse
- [ ] Heartbeat timer for HDS
- [ ] Mock-based unit tests pass
- [ ] Optional @Tags(['ble']) integration test

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=ble
```

## Fixture

docs/protocols/decent-scale-ble.md
