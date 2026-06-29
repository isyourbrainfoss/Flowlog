# Decent Scale — BLE Protocol

**Official source:** <https://decentespresso.com/decentscale_api>

Agent-friendly summary for Flowlog sensor adapters. BLE device name: **`Decent Scale`**.

| Direction | Characteristic UUID |
|-----------|---------------------|
| Notify (weight, buttons, acks) | `0000fff4-0000-1000-8000-00805f9b34fb` |
| Write (commands) | `000036f5-0000-1000-8000-00805f9b34fb` |

Weight notifications arrive at **10 Hz** after the app sends an initial command (tare or LED on). Raw weight is **unsmoothed**.

---

## Packet layout (7-byte commands)

All outbound commands are **7 bytes**:

| Byte | Field | Value |
|------|-------|-------|
| 0 | Model | `0x03` (Decent) |
| 1 | Type | `0x0A` LED, `0x0B` timer, `0x0F` tare |
| 2–5 | Data | Command-specific |
| 6 | XOR | `byte0 ^ byte1 ^ byte2 ^ byte3 ^ byte4 ^ byte5` |

**Half Decent Scale heartbeat:** send `03 0a 03 ff ff 00 0a` at least every **5 s** while connected. Set **byte 6 of tare/LED-on to `0x01`** to opt into heartbeat enforcement (safe on older scales). XOR bytes are deprecated on Half Decent Scale but still required on full Decent Scale.

---

## Common commands (hex, with XOR)

| Action | Hex | Notes |
|--------|-----|-------|
| Tare | `030F000000010D` | Byte 6 = `01` → heartbeat-aware |
| LED on (grams) | `030A0101000108` | Shows **APP** on display; enables weight stream |
| LED off | `030A0000000009` | |
| Timer start | `030B030000000B` | |
| Timer stop | `030B0000000008` | |
| Timer reset | `030B020000000A` | |
| Heartbeat (HDS) | `03 0a 03 ff ff 00 0a` | Required every 5 s on Half Decent Scale |

Send commands **≥200 ms apart**; v1.0 firmware may drop commands — retry once after 50 ms if needed.

---

## FFF4 notify — weight messages

Type byte (index 1): `0xCE` = stable, `0xCA` = changing (optional; Half Decent Scale has no stable concept).

### 7-byte message (firmware v1.0 / v1.1)

```
[03][CE|CA][weight_hi][weight_lo][change_hi][change_lo][xor]
```

### 10-byte message (firmware v1.2+)

```
[03][CE|CA][weight_hi][weight_lo][min][sec][ds][00][00][xor]
```

| Field | Bytes | Decode |
|-------|-------|--------|
| **Weight** | 3–4 (1-based) / indices `[2..3]` | Signed **big-endian** int16 → **grams × 10** → `grams = value / 10.0` |
| Timestamp (v1.2+) | 4–6 | minutes, seconds (0–59), deciseconds (0–9) |
| Change rate (v1.0/v1.1 only) | 4–5 | Buggy; **do not use** — compute flow in app |

**Parsing rule:** Check `data.length`. For weight only, **always read bytes 2–3** — works for both 7- and 10-byte packets.

```dart
// Pseudocode — bytes 2–3 are weight (grams × 10)
final raw = (data[2] << 8 | data[3]).toSigned(16);
final grams = raw / 10.0;
```

### Examples (7-byte)

| Hex | Weight |
|-----|--------|
| `03CE00000000CD` | 0.0 g |
| `03CE00650000A8` | 10.1 g |
| `03CE079400005E` | 194.0 g |
| `03CE1B9300005E` | 705.9 g |

### Examples (10-byte, v1.2+)

| Hex | Weight | Timer |
|-----|--------|-------|
| `03CE00000102030000CD` | 0.0 g | 1:02.3 |
| `03CE00650102040000A8` | 10.1 g | 1:02.4 |

---

## Other FFF4 message types

| Type (byte 1) | Meaning |
|---------------|---------|
| `0xAA` | Button: byte 2 = `01` O / `02` □; byte 3 = `01` short / `02` long |
| `0x0F` | Tare ack: byte 5 = `0xFE` on success |
| `0x0A` | LED command ack: battery % (byte 4), firmware (byte 5) |

---

## Integration notes

- Connect → subscribe **FFF4** → send **LED on** or **tare** to start weight stream.
- Flowlog: Half Decent Scale heartbeat every 5 s (`03 0a 03 ff ff 00 0a`).
- Merge weight samples on **host receive time**, not device timestamp (see `docs/AGENT_GUIDE.md`).
- Max weight **2000 g**; implement smoothing in software if needed.

---

## WiFi mode (openscale 3.x)

Half Decent Scale firmware **3.0+** exposes a WebSocket endpoint when WiFi is enabled.

| Item | Value |
|------|-------|
| Endpoint | `ws://{host}/snapshot` (default host: `hds.local` via mDNS) |
| Discovery | DNS-SD `_decentscale._tcp` |
| Default rate | 2 Hz weight snapshots |

### Weight snapshot (untyped)

Absence of `type` means a weight frame:

```json
{"grams": 25.66, "ms": 12345}
```

| Field | Meaning |
|-------|---------|
| `grams` | Weight in grams (double) |
| `ms` | Device monotonic timestamp (ms) |

Flowlog stamps samples on **host receive time**, not device `ms`.

### Commands (text)

```
tare
rate 2k
rate 5k
rate 10k
status
```

Legacy `tare` is silent (no ack). JSON `{"command":"tare"}` returns a typed status ack.

### Flowlog adapter

`WifiScaleAdapter` in `flowlog_sensors` connects to `/snapshot`, sends `rate 2k` on connect, parses untyped `grams`/`ms` frames, and exposes `tare()`.