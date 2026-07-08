# Flowlog

Personal coffee intelligence hub — live shot curves, history, bean library, and sensor tooling.

## Android testing

### USB (best for development)

USB debugging is the preferred way while you are actively developing:

1. On your phone: **Settings → Developer options → USB debugging** (enable).
2. Connect via USB and tap **Allow** on the authorization prompt.
3. Point the app at a full Android SDK (Arch's `/opt/android-sdk` is often platform-tools only):

```bash
# One-time setup (example: user-local SDK)
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"

# app/flowlog/android/local.properties should contain:
# sdk.dir=/home/<you>/Android/Sdk
```

4. From this repo:

```bash
cd app/flowlog
flutter pub get
flutter devices          # confirm your phone is listed (e.g. FP5)
flutter run -d <device>  # debug build with hot reload
```

Useful variants:

```bash
flutter run --release    # closer to production performance
flutter logs             # stream device logs
```

Wireless ADB works too, but USB is simpler for first-time setup and is more reliable for logs/hot reload.

### Obtainium (best for installing latest builds)

[Obtainium](https://github.com/ImranR98/Obtainium) installs APKs directly from a release source and
can notify you when updates are available. A new arm64 APK is published on every push to `main`.

#### Recommended: Standard JSON (stable mirror)

GitHub Release asset URLs (`release-assets.githubusercontent.com`) often fail on phones with
*Connection closed while receiving data*. Use the `gh-pages` mirror instead (same approach as
[gator-flutter](https://github.com/isyourbrainfoss/gator-flutter)).

1. Install Obtainium from F-Droid, IzzyOnDroid, or its [GitHub releases](https://github.com/ImranR98/Obtainium/releases).
2. **Add app** → source type **Direct APK Link** (Obtainium auto-detects JSON).
3. Paste this URL:

   ```
   https://raw.githubusercontent.com/isyourbrainfoss/Flowlog/gh-pages/version.json
   ```

4. Tap **Get updates** / install.

`version.json` includes `versionCode`, `sha256sum`, and the APK URL. CI refreshes it on each build.

**One-tap add (Obtainium installed):**

```
https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://raw.githubusercontent.com/isyourbrainfoss/Flowlog/gh-pages/version.json
```

#### Troubleshooting Obtainium

| Symptom | Fix |
|---------|-----|
| **`error [App]` or `Conflict [App]`** | `[App]` is Obtainium’s placeholder name before the first successful install — not the problem. Open **Settings → Logs** in Obtainium for the real message. `Conflict` = an old USB/debug build is still installed with a different signing key; uninstall `flowlog` first (Settings → Apps, or `adb uninstall com.flowlog.flowlog`). |
| **“App not installed” / signature error** | Same as `Conflict` above: remove the old build, then install fresh from `version.json`. |
| **“Connection closed while receiving data”** | Do not use GitHub Release download URLs on mobile. Remove the app in Obtainium and re-add using `version.json`, not `github.com/.../releases/download/...`. |
| **Still on an old Obtainium entry** | Remove Flowlog in Obtainium, re-add with the `version.json` URL. |

#### Alternative: Direct APK Link

If JSON does not work in your Obtainium version:

```
https://raw.githubusercontent.com/isyourbrainfoss/Flowlog/gh-pages/flowlog-arm64-v8a.apk
```

#### Alternative: GitHub Releases

```
https://github.com/isyourbrainfoss/Flowlog
```

APK filter: `flowlog-arm64-v8a\.apk` or `flowlog-release\.apk`

## Linux (Flatpak)

Flowlog is published as a Flatpak for **x86_64** desktops and **aarch64** Linux phones
(PostmarketOS, Mobian, etc.). It is not on Flathub; install from the project's GitHub
Pages remote or from release bundles.

### Install from remote (recommended)

One-time setup:

```bash
flatpak remote-add --if-not-exists --user flowlog \
  https://raw.githubusercontent.com/isyourbrainfoss/Flowlog/gh-pages/flowlog.flatpakrepo
flatpak install --user flowlog com.flowlog.flowlog
```

Updates:

```bash
flatpak update --user com.flowlog.flowlog
```

The GNOME 48 runtime is pulled from Flathub automatically on first install.

### Install from a release bundle (offline)

Download the `.flatpak` file for your architecture from
[GitHub Releases](https://github.com/isyourbrainfoss/Flowlog/releases), then:

```bash
# x86_64 desktop
flatpak install --user --bundle com.flowlog.flowlog-x86_64.flatpak

# aarch64 / ARM Linux phone
flatpak install --user --bundle com.flowlog.flowlog-aarch64.flatpak
```

### Build locally

```bash
./flatpak/build-flatpak.sh          # current machine arch
./flatpak/build-flatpak.sh x86_64   # or aarch64
```

> **Note:** GitHub Pages must be enabled for the repository (Settings → Pages →
> "GitHub Actions" source) so the Flatpak remote URL stays online.

## Development

```bash
flutter pub get
melos run test
melos run analyze
melos run run:linux
```

## Structure

| Path | Purpose |
|------|---------|
| `app/flowlog` | Flutter app |
| `packages/flowlog_core` | Models, database, repositories |
| `packages/flowlog_charts` | Live/history charts |
| `packages/flowlog_sensors` | BLE sensor adapters |
| `fixtures/` | Test/replay data |