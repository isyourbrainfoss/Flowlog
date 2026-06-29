# SLICE-A1: Flutter workspace + melos

status: done
parallel_with: none

## Prerequisites

None (first slice).

## Scope

- Root `pubspec.yaml` (Dart workspace + melos scripts)
- `app/flowlog` Flutter application (Android + Linux)
- `packages/flowlog_core`, `packages/flowlog_sensors`, `packages/flowlog_charts` package skeletons
- `fixtures/`, `docs/slices/`, `docs/protocols/` directory placeholders

## Done when

- [x] `melos bootstrap` resolves all workspace packages
- [x] Empty Flowlog app launches on Linux (`flutter run -d linux`)
- [x] Android project scaffold present (`app/flowlog/android/`)
- [x] Workspace tests pass (`melos run test`)

## Verify

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
cd /home/kb/repos/grok_build/Flowlog
melos bootstrap
melos run test
cd app/flowlog && flutter run -d linux
```

## Fixture

none

## Notes

- Android emulator requires `cmdline-tools` in Android SDK (`flutter doctor` will flag if missing).
- BLE/hardware slices use mocks; no devices needed for A1.