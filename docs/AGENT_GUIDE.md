# Flowlog — Agent Guide

## Picking up work

1. Check [`PARALLEL.md`](PARALLEL.md) for slices safe to run **right now**.
2. Open [`slices/SLICE-XX.md`](slices/) — confirm prerequisites are `done`.
3. Implement **only** paths listed under Scope.
4. Run the **Verify** command; fix until green.
5. Set `status: done` in the slice file header.
6. Update [`BACKLOG.md`](BACKLOG.md) status column for that row.

## Repo layout

| Path | Purpose |
|------|---------|
| `app/flowlog/` | Flutter UI shell |
| `packages/flowlog_core/` | Models, DB, shot session, export (pure Dart) |
| `packages/flowlog_sensors/` | BLE adapters + mock replay (pure Dart) |
| `packages/flowlog_charts/` | Live chart widgets (Flutter) |
| `fixtures/` | Golden shots and prerecorded sensor streams |
| `docs/protocols/` | Vendored Pressensor + Decent Scale BLE notes |
| `docs/slices/` | One spec file per slice (A1–G6) |
| `docs/PARALLEL.md` | Multi-agent wave guide |
| `docs/BACKLOG.md` | Master slice table |
| `docs/PLAN.md` | Architecture and design decisions |

## Commands

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
dart pub get             # at repo root, after workspace pubspec changes
melos bootstrap          # links workspace packages
melos run test           # all tests
melos run analyze        # flutter analyze
melos run run:linux      # run app on Linux
```

## Golden rules

- **No slice requires hardware.** Use `MockReplayAdapter` and fixtures.
- BLE integration tests are tagged `ble` and optional locally.
- Merge sensor clocks on **host receive time**, not device timestamps.
- Half Decent Scale: heartbeat `03 0a 03 ff ff 00 0a` every 5 s when connected.
- If two slices share a Scope path, **do not** run them in parallel.

## Slice index

| Layer | IDs | Specs |
|-------|-----|-------|
| Scaffold | A1–A6 | [`slices/`](slices/) |
| Sensors | B1–B7 | |
| Live shot | C1–C8 | |
| History | D1–D5 | |
| Polish | E1–E7 | |
| Library | F1–F7 | |
| Future | G1–G6 | |

## Spawn prompt (copy-paste)

```text
Read docs/AGENT_GUIDE.md and docs/slices/SLICE-A3.md.
Implement only that slice. Run Verify. Set status: done.
Do not edit files outside Scope.
```