# SLICE-B1: SensorAdapter + SensorSample

status: done
parallel_with: A6

## Prerequisites

A3

## Scope

- `packages/flowlog_sensors/lib/src/adapter.dart`
- `packages/flowlog_sensors/lib/src/sample.dart`

## Done when

- [x] SensorSample with t, pressureBar?, weightG?, tempC?
- [x] SensorAdapter abstract interface
- [x] ConnectionState enum

## Verify

```bash
cd packages/flowlog_sensors && dart test
```

## Fixture

none
