# SLICE-G6: WiFi scale adapter

status: pending
parallel_with: none

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/wifi_scale/`

## Done when

- [ ] WebSocket client for openscale 3.x
- [ ] Parse grams/ms frames
- [ ] tare command

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=wifi
```

## Fixture

docs/protocols/decent-scale-ble.md (WiFi section)
