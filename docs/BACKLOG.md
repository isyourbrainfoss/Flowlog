# Slice backlog

Full specs: [`docs/slices/`](slices/) (one file per slice).

Parallel waves: [`docs/PARALLEL.md`](PARALLEL.md).

| ID | Title | Status | Can parallel with |
|----|-------|--------|-------------------|
| A1 | Flutter workspace + melos | done | — |
| A2 | Vendored protocol docs | done | A3, A5 |
| A3 | flowlog_core models | done | A2, A5 |
| A4 | SQLite schema + migrations | done | A5, A6 |
| A5 | Adaptive shell + 4 tabs | done | A2, A3, A4, A6 |
| A6 | Coffee dark theme | done | A4 |
| B1 | SensorAdapter + SensorSample | done | A6 |
| B2 | MockReplayAdapter | done | B4, B5, B3 |
| B3 | Flow rate derivation | done | B2, B4, B5 |
| B4 | DecentScaleBleAdapter | done | B2, B5, B3 |
| B5 | PressensorBleAdapter | done | B2, B4, B3 |
| B6 | MergedSampleStream | done | C1 |
| B7 | Device manager UI stub | done | C3 |
| C1 | ShotSession state machine | done | C3, B6, B7 |
| C2 | Start/Stop + auto-tare | done | C4, C5 |
| C3 | DualCurveChart live | done | C1, C4, B7 |
| C4 | Floating metrics row | done | C5, C2 |
| C5 | Shot metadata sheet | done | C4, C6, C2 |
| C6 | Save shot + God Shot FAB | pending | C8, D1 |
| C7 | Auto shot detect | done | C8 |
| C8 | Top bar sensor status | pending | C7, D1 |
| D1 | History card list | pending | D3, F4 |
| D2 | Shot detail view | pending | D4 |
| D3 | CSV export single shot | pending | D1, D4 |
| D4 | CSV batch export + share | pending | D5 |
| D5 | CSV import | pending | F1 |
| E1 | Chart zoom/pan + view modes | pending | E2, E6 |
| E2 | Annotations + channel mark | pending | E1, E3 |
| E3 | Haptics + shot-end pulse | pending | E4, E2 |
| E4 | Bean fill + PB confetti | pending | E3 |
| E5 | Desktop keyboard shortcuts | pending | E6 |
| E6 | Accessibility pass | pending | E1, E5 |
| E7 | Sensor diagnostics | pending | E6 |
| F1 | Search + filter shots | pending | F2, F4 |
| F2 | Tags / folders | pending | F1, F4 |
| F3 | Side-by-side compare | pending | F6 |
| F4 | Bean database | pending | F1, F2 |
| F5 | Saved profiles + Repeat shot | pending | F6 |
| F6 | Insights dashboard | pending | F7, F3 |
| F7 | PDF export | pending | F3 |
| G1 | AI insights tab | pending | G2 |
| G2 | What-if curve simulator | pending | G1 |
| G3 | E2E cloud sync | pending | G4 |
| G4 | Community profile share | pending | G3 |
| G5 | Android home widget | pending | — |
| G6 | WiFi scale adapter | pending | — |