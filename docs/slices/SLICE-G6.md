# SLICE-G6: WiFi scale adapter

status: done
parallel_with: none

## Prerequisites

B1

## Scope

- `packages/flowlog_sensors/lib/src/wifi_scale/`

## Done when

- [x] WebSocket client for openscale 3.x
- [x] Parse grams/ms frames
- [x] tare command

## Verify

```bash
cd packages/flowlog_sensors && dart test --exclude-tags=wifi
```

## Fixture

docs/protocols/decent-scale-ble.md (WiFi section)
