# Flowlog versioning

## Marketing version (pubspec)

`app/flowlog/pubspec.yaml` holds the marketing version, currently `0.0.3+3`
(`versionName`+`versionCode` defaults for local builds).

## Android CI releases

The [Android Release](../.github/workflows/android-release.yml) workflow:

| Field | Value |
|-------|-------|
| GitHub release tag | `build-${{ github.run_number }}` (unchanged) |
| APK `versionName` (`--build-name`) | pubspec marketing version (e.g. `0.0.3`) |
| APK `versionCode` (`--build-number`) | `${{ github.run_number }}` |
| Obtainium `version` / `versionName` | marketing version (e.g. `0.0.3`) |
| Obtainium `versionCode` | CI run number |

Obtainium update detection uses `versionCode`, so switching `versionName` from
`build-N` to `0.0.3` does not break updates. The About screen shows
`PackageInfo.version` + `buildNumber` from the installed APK.
