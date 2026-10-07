# Flowlog versioning

## Marketing version (pubspec)

`app/flowlog/pubspec.yaml` holds the marketing version, currently `0.0.4+4`
(`versionName`+`versionCode` defaults for local builds).

## Android CI releases

The [Android Release](../.github/workflows/android-release.yml) workflow:

| Field | Value |
|-------|-------|
| GitHub release tag | `build-${{ github.run_number }}` (unchanged) |
| APK `versionName` (`--build-name`) | pubspec marketing version (e.g. `0.0.4`) |
| APK `versionCode` (`--build-number`) | `${{ github.run_number }}` |
| Obtainium `version` / `versionName` | marketing version (e.g. `0.0.4`) |
| Obtainium `versionCode` | CI run number |

Obtainium update detection uses `versionCode`, so switching `versionName` from
`build-N` to a marketing version does not break updates. The About screen shows
`PackageInfo.version` + `buildNumber` from the installed APK.

## History

| Marketing | Notable changes |
|-----------|-----------------|
| `0.0.4` | Live RSSI in Sensor diagnostics while connected; `live_screen.dart` split into `screens/live/live_*.dart` pieces (no UI change); Nextcloud screen no longer promises future E2E sync encryption. |
| `0.0.3` | Marketing `versionName` in APK/Obtainium (tags stay `build-N`). |
