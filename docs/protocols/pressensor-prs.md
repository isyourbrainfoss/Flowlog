# Pressensor PRS — BLE Protocol

**Official source:** <https://pressensor.com/pages/prs-protocol>

Agent-friendly summary for Flowlog sensor adapters. Connect via BLE; advertising name prefix is **`PRS`**.

---

## Services & characteristics

| Role | UUID | Access | Payload |
|------|------|--------|---------|
| Pressure Service | `873ae82a-4c5a-4342-b539-9d900bf7ebd0` | — | — |
| Pressure (live) | `873ae82b-4c5a-4342-b539-9d900bf7ebd0` | notify | See [Pressure notify](#pressure-notify) |
| Zero pressure (tare) | `873ae82c-4c5a-4342-b539-9d900bf7ebd0` | write | Any value → current pressure treated as zero |
| Battery Service | `0000180f-0000-1000-8000-00805f9b34fb` | — | Standard BLE |
| Battery level | `00002a19-0000-1000-8000-00805f9b34fb` | read | `0…100` (percent) |
| Log Service | `873ae828-4c5a-4342-b539-9d900bf7ebd0` | — | — |
| Log | `873ae829-4c5a-4342-b539-9d900bf7ebd0` | notify | Null-terminated string |

---

## Pressure notify

Subscribe to **Pressure** (`873ae82b-…`). Each notification is **2 or 4 bytes**, big-endian signed integers:

| Notification # | Bytes | Type | Unit | Decode |
|----------------|-------|------|------|--------|
| Every | 0–1 | Pressure | millibar | `int16_be(data[0:2])` → mbar |
| Every 16th | 0–1 | Pressure | millibar | same |
| Every 16th | 2–3 | Temperature | 0.1 °C | `int16_be(data[2:4]) / 10.0` → °C |

**Parsing rule:** On notifications 1–15, 17–31, … (not divisible by 16), payload is **2 bytes** (pressure only). On notifications 16, 32, … payload is **4 bytes** (pressure + temperature).

```dart
// Pseudocode
final mbar = (data[0] << 8 | data[1]).toSigned(16);
if (data.length >= 4) {
  final tempC = ((data[2] << 8 | data[3]).toSigned(16)) / 10.0;
}
```

Flowlog maps mbar to bar for shot charts (`mbar / 1000`).

---

## Integration notes

- **Tare:** write any value to Zero Pressure (`873ae82c-…`).
- **Battery:** optional read on standard Battery Level characteristic (`0…100` %). Flowlog reads this on connect and warns at ≤20%.
- **Temperature:** bundled on every 16th pressure notify (see above). Flowlog records it on shot samples and shows it on the Live metrics row.
- **Log:** optional notify on Log characteristic — null-terminated diagnostic strings (not used by Flowlog yet).
- **Clock:** merge samples on **host receive time** (see `docs/AGENT_GUIDE.md`).