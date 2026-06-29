#!/usr/bin/env python3
"""Generate docs/slices/SLICE-*.md from the manifest."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SLICES_DIR = ROOT / "docs" / "slices"

SLICES = [
    # id, title, status, prerequisites, parallel_with, scope, done_when, verify, fixture
    ("A1", "Flutter workspace + melos", "done", [], [],
     ["Root pubspec.yaml workspace", "app/flowlog", "packages/*", "melos scripts"],
     ["melos bootstrap resolves 4 packages", "App runs on Linux", "Android scaffold present", "melos run test passes"],
     "export PATH=\"$PATH:$HOME/.pub-cache/bin\" && cd /home/kb/repos/grok_build/Flowlog && melos bootstrap && melos run test",
     "none"),
    ("A2", "Vendored protocol docs", "pending", ["A1"], ["A3", "A5"],
     ["docs/protocols/pressensor-prs.md", "docs/protocols/decent-scale-ble.md"],
     ["Pressensor PRS BLE UUIDs and notify format documented", "Decent Scale BLE commands and FFF4 parse format documented", "Links to official sources in doc headers"],
     "test -f docs/protocols/pressensor-prs.md && test -f docs/protocols/decent-scale-ble.md",
     "none"),
    ("A3", "flowlog_core models", "pending", ["A1"], ["A2", "A5"],
     ["packages/flowlog_core/lib/src/models/", "packages/flowlog_core/test/models_test.dart"],
     ["Shot, ShotSample, Bean, Device types defined", "toJson/fromJson round-trip tests pass", "Exported from flowlog_core.dart"],
     "cd packages/flowlog_core && dart test",
     "fixtures/shots/minimal_shot.json (added in slice)"),
    ("A4", "SQLite schema + migrations", "pending", ["A3"], ["A5", "A6"],
     ["packages/flowlog_core/lib/src/db/", "packages/flowlog_core/test/db_test.dart"],
     ["drift (or sqlite) schema for shots + samples", "Insert and read shot with samples", "Migration from v1 works"],
     "cd packages/flowlog_core && dart test test/db_test.dart",
     "fixtures/shots/minimal_shot.json"),
    ("A5", "Adaptive shell + 4 tabs", "pending", ["A1"], ["A2", "A3", "A4", "A6"],
     ["app/flowlog/lib/shell/", "app/flowlog/lib/screens/"],
     ["Live, History, Library, More routes exist", "NavigationRail below 600dp width", "Sidebar with labels at 600dp+", "Placeholder body per tab"],
     "cd app/flowlog && flutter test",
     "none"),
    ("A6", "Coffee dark theme", "pending", ["A5"], ["A4"],
     ["app/flowlog/lib/theme/"],
     ["coffeeDark ColorScheme and text theme", "cafeLight variant defined", "Theme toggle stub in More tab"],
     "cd app/flowlog && flutter test && flutter analyze",
     "none"),
    ("B1", "SensorAdapter + SensorSample", "pending", ["A3"], ["A6"],
     ["packages/flowlog_sensors/lib/src/adapter.dart", "packages/flowlog_sensors/lib/src/sample.dart"],
     ["SensorSample with t, pressureBar?, weightG?, tempC?", "SensorAdapter abstract interface", "ConnectionState enum"],
     "cd packages/flowlog_sensors && dart test",
     "none"),
    ("B2", "MockReplayAdapter", "pending", ["B1"], ["B4", "B5", "B3"],
     ["packages/flowlog_sensors/lib/src/mock/", "fixtures/sensor_streams/demo_shot.jsonl"],
     ["Replays jsonl fixture at configurable speed", "Emits SensorSample stream", "Unit test counts samples"],
     "cd packages/flowlog_sensors && dart test",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("B3", "Flow rate derivation", "pending", ["A3"], ["B2", "B4", "B5"],
     ["packages/flowlog_core/lib/src/flow_rate.dart"],
     ["weightG series to smoothed flowGs", "Unit tests match golden values", "Handles gaps in samples"],
     "cd packages/flowlog_core && dart test test/flow_rate_test.dart",
     "fixtures/sensor_streams/flow_rate_golden.json"),
    ("B4", "DecentScaleBleAdapter", "pending", ["B1"], ["B2", "B5", "B3"],
     ["packages/flowlog_sensors/lib/src/decent_scale/", "docs/protocols/decent-scale-ble.md"],
     ["LED on, tare, FFF4 parse", "Heartbeat timer for HDS", "Mock-based unit tests pass", "Optional @Tags(['ble']) integration test"],
     "cd packages/flowlog_sensors && dart test --exclude-tags=ble",
     "docs/protocols/decent-scale-ble.md"),
    ("B5", "PressensorBleAdapter", "pending", ["B1"], ["B2", "B4", "B3"],
     ["packages/flowlog_sensors/lib/src/pressensor/", "docs/protocols/pressensor-prs.md"],
     ["Scan PRS* devices", "Subscribe pressure notify, parse mbar", "Zero pressure write", "Mock-based unit tests pass"],
     "cd packages/flowlog_sensors && dart test --exclude-tags=ble",
     "docs/protocols/pressensor-prs.md"),
    ("B6", "MergedSampleStream", "pending", ["B4", "B5"], ["C1"],
     ["packages/flowlog_sensors/lib/src/merged_stream.dart"],
     ["Merges pressure + weight on host monotonic clock", "Works with only one sensor connected", "Unit test with two mock adapters"],
     "cd packages/flowlog_sensors && dart test test/merged_stream_test.dart",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("B7", "Device manager UI stub", "pending", ["A5", "B1"], ["C3"],
     ["app/flowlog/lib/screens/more/sensors_screen.dart"],
     ["More tab shows Sensors section", "Placeholder paired device list", "Connection state chips (mock)"],
     "cd app/flowlog && flutter test",
     "none"),
    ("C1", "ShotSession state machine", "pending", ["A4", "B2"], ["C3", "B6", "B7"],
     ["packages/flowlog_core/lib/src/shot_session.dart"],
     ["States: idle, recording, paused, stopped", "Emits sample batches to listeners", "Unit tests cover transitions"],
     "cd packages/flowlog_core && dart test test/shot_session_test.dart",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("C2", "Start/Stop + auto-tare", "pending", ["C1"], ["C4", "C5"],
     ["app/flowlog/lib/screens/live/controls.dart"],
     ["Start begins recording via ShotSession", "Stop finalizes session", "Start sends tare to mock/scale adapter"],
     "cd app/flowlog && flutter test",
     "none"),
    ("C3", "DualCurveChart live", "pending", ["B3", "B2"], ["C1", "C4", "B7"],
     ["packages/flowlog_charts/lib/src/dual_curve_chart.dart"],
     ["Pressure + weight/flow curves", "Driven by mock stream in widget test", "Repaint boundary for performance"],
     "cd packages/flowlog_charts && flutter test",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("C4", "Floating metrics row", "pending", ["C3"], ["C5", "C2"],
     ["app/flowlog/lib/screens/live/metrics_row.dart"],
     ["Shows pressure, flow, elapsed, projected yield", "Trend arrows on change"],
     "cd app/flowlog && flutter test",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("C5", "Shot metadata sheet", "pending", ["A3"], ["C4", "C6", "C2"],
     ["app/flowlog/lib/screens/live/metadata_sheet.dart"],
     ["Dose, yield, grind, bean, temp, notes", "Taste 0-10 slider", "Flavour tag chips"],
     "cd app/flowlog && flutter test",
     "fixtures/shots/minimal_shot.json"),
    ("C6", "Save shot + God Shot FAB", "pending", ["C2", "C5"], ["C8", "D1"],
     ["app/flowlog/lib/screens/live/save_shot.dart"],
     ["Persist samples + metadata to DB", "God Shot FAB visible on Live", "Success snackbar"],
     "cd packages/flowlog_core && dart test && cd ../../app/flowlog && flutter test",
     "fixtures/shots/minimal_shot.json"),
    ("C7", "Auto shot detect", "pending", ["C1", "B3"], ["C8"],
     ["packages/flowlog_core/lib/src/shot_detect.dart"],
     ["First flow > threshold sets t=0", "Configurable threshold in settings stub", "Unit tested"],
     "cd packages/flowlog_core && dart test test/shot_detect_test.dart",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("C8", "Top bar sensor status", "pending", ["A5", "B7"], ["C7", "D1"],
     ["app/flowlog/lib/shell/top_bar.dart"],
     ["Bean name + quick edit", "PRS + scale connection icons"],
     "cd app/flowlog && flutter test",
     "none"),
    ("D1", "History card list", "pending", ["C6"], ["D3", "F4"],
     ["app/flowlog/lib/screens/history/", "packages/flowlog_charts sparkline"],
     ["Cards with sparkline, peak P, yield, taste", "Sorted by date desc"],
     "cd app/flowlog && flutter test",
     "fixtures/shots/minimal_shot.json"),
    ("D2", "Shot detail view", "pending", ["D1", "C3"], ["D4"],
     ["app/flowlog/lib/screens/history/shot_detail.dart"],
     ["Full chart + read-only metadata", "Navigate from history card"],
     "cd app/flowlog && flutter test",
     "fixtures/shots/minimal_shot.json"),
    ("D3", "CSV export single shot", "pending", ["C6"], ["D1", "D4"],
     ["packages/flowlog_core/lib/src/export/csv.dart"],
     ["Export matches golden CSV byte-for-byte", "Unit test"],
     "cd packages/flowlog_core && dart test test/csv_export_test.dart",
     "fixtures/shots/minimal_shot.csv"),
    ("D4", "CSV batch export + share", "pending", ["D3"], ["D5"],
     ["app/flowlog/lib/screens/more/export.dart"],
     ["Export multiple shots", "Linux save dialog", "Android share stub or platform channel"],
     "cd app/flowlog && flutter test",
     "fixtures/shots/"),
    ("D5", "CSV import", "pending", ["D3"], ["F1"],
     ["packages/flowlog_core/lib/src/export/csv_import.dart"],
     ["Import exported CSV", "Round-trip identical shot in DB"],
     "cd packages/flowlog_core && dart test test/csv_roundtrip_test.dart",
     "fixtures/shots/minimal_shot.csv"),
    ("E1", "Chart zoom/pan + view modes", "pending", ["C3"], ["E2", "E6"],
     ["packages/flowlog_charts/lib/src/chart_interaction.dart"],
     ["Pinch/zoom and pan", "Swipe overlay/split/flow-only modes"],
     "cd packages/flowlog_charts && flutter test",
     "fixtures/sensor_streams/demo_shot.jsonl"),
    ("E2", "Annotations + channel mark", "pending", ["C3", "C6"], ["E1", "E3"],
     ["packages/flowlog_core annotation model", "app/flowlog chart overlays"],
     ["Long-press to annotate", "Mark channel button", "Undo stack", "Persisted on shot"],
     "melos run test",
     "none"),
    ("E3", "Haptics + shot-end pulse", "pending", ["C4"], ["E4", "E2"],
     ["app/flowlog/lib/screens/live/feedback.dart"],
     ["Flow stability pulse animation", "Shot-end haptic/sound hook"],
     "cd app/flowlog && flutter test",
     "none"),
    ("E4", "Bean fill + PB confetti", "pending", ["C2"], ["E3"],
     ["app/flowlog/lib/screens/live/delight.dart"],
     ["Bean icon fills during shot", "Confetti on personal best taste score"],
     "cd app/flowlog && flutter test",
     "none"),
    ("E5", "Desktop keyboard shortcuts", "pending", ["A5", "C2"], ["E6"],
     ["app/flowlog/lib/shell/shortcuts.dart"],
     ["Space toggles start/stop", "Ctrl+E triggers export"],
     "cd app/flowlog && flutter test",
     "none"),
    ("E6", "Accessibility pass", "pending", ["A5", "C3"], ["E1", "E5"],
     ["app/flowlog a11y labels", "packages/flowlog_charts colorblind palette"],
     ["Semantics labels on controls", "High contrast option stub", "Colour-blind safe chart colors"],
     "cd app/flowlog && flutter test",
     "none"),
    ("E7", "Sensor diagnostics", "pending", ["B7"], ["E6"],
     ["app/flowlog/lib/screens/more/diagnostics.dart"],
     ["RSSI display", "Reconnect log", "Last error message"],
     "cd app/flowlog && flutter test",
     "none"),
    ("F1", "Search + filter shots", "pending", ["D1"], ["F2", "F4"],
     ["app/flowlog/lib/screens/history/filters.dart"],
     ["Filter by bean, date, taste, peak pressure"],
     "cd app/flowlog && flutter test",
     "none"),
    ("F2", "Tags / folders", "pending", ["D1"], ["F1", "F4"],
     ["packages/flowlog_core tags model", "app/flowlog tag UI"],
     ["CRUD tags", "Filter history by tag"],
     "melos run test",
     "none"),
    ("F3", "Side-by-side compare", "pending", ["D2", "F1"], ["F6"],
     ["app/flowlog/lib/screens/library/compare.dart"],
     ["Overlay 2+ shots", "Optional delta highlight"],
     "cd app/flowlog && flutter test",
     "fixtures/shots/"),
    ("F4", "Bean database", "pending", ["A4", "C6"], ["F1", "F2"],
     ["app/flowlog/lib/screens/library/beans.dart"],
     ["CRUD beans", "Link shots to bean", "Stock field"],
     "melos run test",
     "none"),
    ("F5", "Saved profiles + Repeat shot", "pending", ["C6", "C3"], ["F6"],
     ["packages/flowlog_core profiles", "app/flowlog repeat button"],
     ["Save cranking pattern from shot", "One-tap Repeat prefill"],
     "melos run test",
     "none"),
    ("F6", "Insights dashboard", "pending", ["D1", "F4"], ["F7", "F3"],
     ["app/flowlog/lib/screens/library/insights.dart"],
     ["Trend charts e.g. avg peak P by roast"],
     "cd app/flowlog && flutter test",
     "none"),
    ("F7", "PDF export", "pending", ["D2"], ["F3"],
     ["packages/flowlog_core/lib/src/export/pdf.dart"],
     ["Single shot PDF report", "Unit test output structure"],
     "cd packages/flowlog_core && dart test test/pdf_export_test.dart",
     "fixtures/shots/minimal_shot.json"),
    ("G1", "AI insights tab", "pending", ["F4", "D2"], ["G2"],
     ["app/flowlog/lib/screens/library/ai_insights.dart"],
     ["Taste notes input", "Rule-based tweak suggestions stub", "Anomaly hints from curve"],
     "cd app/flowlog && flutter test",
     "none"),
    ("G2", "What-if curve simulator", "pending", ["C3", "F5"], ["G1"],
     ["app/flowlog/lib/screens/library/simulator.dart"],
     ["Drag target pressure profile", "Predicted flow display stub"],
     "cd app/flowlog && flutter test",
     "none"),
    ("G3", "E2E cloud sync", "pending", ["D5"], ["G4"],
     ["packages/flowlog_core/lib/src/sync/"],
     ["Encrypted blob export/import stub", "Optional account-off by default"],
     "cd packages/flowlog_core && dart test",
     "none"),
    ("G4", "Community profile share", "pending", ["F5"], ["G3"],
     ["app/flowlog share profile flow"],
     ["Anonymised export link generation stub"],
     "cd app/flowlog && flutter test",
     "none"),
    ("G5", "Android home widget", "pending", ["C3"], [],
     ["android widget module"],
     ["Live mini-graph widget stub"],
     "cd app/flowlog && flutter analyze",
     "none"),
    ("G6", "WiFi scale adapter", "pending", ["B1"], [],
     ["packages/flowlog_sensors/lib/src/wifi_scale/"],
     ["WebSocket client for openscale 3.x", "Parse grams/ms frames", "tare command"],
     "cd packages/flowlog_sensors && dart test --exclude-tags=wifi",
     "docs/protocols/decent-scale-ble.md (WiFi section)"),
]


def render_slice(s):
    sid, title, status, prereqs, parallel_with, scope, done_when, verify, fixture = s
    prereq_line = ", ".join(prereqs) if prereqs else "None"
    parallel_line = ", ".join(parallel_with) if parallel_with else "none"
    scope_bullets = "\n".join(f"- `{p}`" for p in scope)
    done_bullets = "\n".join(f"- [ ] {d}" for d in done_when)
    check = "x" if status == "done" else " "

    return f"""# SLICE-{sid}: {title}

status: {status}
parallel_with: {parallel_line}

## Prerequisites

{prereq_line}

## Scope

{scope_bullets}

## Done when

{done_bullets.replace('- [ ]', f'- [{check}]', 1) if status == 'done' else done_bullets}
{'' if status != 'done' else ''.join(chr(10) + '- [' + ('x' if status == 'done' else ' ') + '] ' + d[4:] if False else '' for d in done_when)}
"""

# Fix done_when for done status - rewrite render function properly

def render_slice_fixed(s):
    sid, title, status, prereqs, parallel_with, scope, done_when, verify, fixture = s
    prereq_line = ", ".join(prereqs) if prereqs else "None"
    parallel_line = ", ".join(parallel_with) if parallel_with else "none"
    scope_bullets = "\n".join(f"- `{p}`" for p in scope)
    mark = "x" if status == "done" else " "
    done_bullets = "\n".join(f"- [{mark}] {d}" for d in done_when)

    return f"""# SLICE-{sid}: {title}

status: {status}
parallel_with: {parallel_line}

## Prerequisites

{prereq_line}

## Scope

{scope_bullets}

## Done when

{done_bullets}

## Verify

```bash
{verify}
```

## Fixture

{fixture}
"""


def main():
    SLICES_DIR.mkdir(parents=True, exist_ok=True)
    for s in SLICES:
        path = SLICES_DIR / f"SLICE-{s[0]}.md"
        path.write_text(render_slice_fixed(s), encoding="utf-8")
        print(f"wrote {path.name}")


if __name__ == "__main__":
    main()