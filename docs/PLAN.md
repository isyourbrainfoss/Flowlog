# Flowlog plan (summary)

Full slice specs live in [`slices/`](slices/). Parallel waves: [`PARALLEL.md`](PARALLEL.md).

## Vision

Personal coffee intelligence hub for CJ2 + Pressensor + DIY ESP scale. Libadwaita-*inspired* Flutter UI (dark/warm coffee palette). Android, Linux desktop, Linux mobile — same adaptive layout, narrower on small screens.

## Stack

- **UI:** Flutter 3, `NavigationRail` / sidebar by breakpoint
- **Core:** Dart package `flowlog_core` — drift/SQLite, models, shot session, CSV
- **Sensors:** `flowlog_sensors` — `flutter_blue_plus`, mock replay first
- **Charts:** `flowlog_charts` — `CustomPainter` live curves

## Protocols

- Pressensor PRS BLE → [`protocols/pressensor-prs.md`](protocols/pressensor-prs.md) (A2)
- Decent Scale BLE → [`protocols/decent-scale-ble.md`](protocols/decent-scale-ble.md) (A2)

## Adaptive layout

| Width / height | Layout |
|----------------|--------|
| &lt; 600dp wide **or** &lt; 320dp tall | Bottom nav bar (icons only) |
| 600dp+ wide and tall enough | Sidebar with icon + text labels |
| 900dp+ | Split panels + keyboard shortcuts |

## MVP path

`A1` → `A2|A3|A5` (parallel) → `A4` + `A6` → `B1` → `B2|B3|B4|B5` → `C1|C3` → `C6` → `D1|D3`

See [`PARALLEL.md`](PARALLEL.md) for agent waves.