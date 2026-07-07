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

This repo publishes a release APK on every push to `main`. Install and update with [Obtainium](https://github.com/ImranR98/Obtainium):

1. Install Obtainium on your phone.
2. Add app → **GitHub**.
3. Source URL: `https://github.com/isyourbrainfoss/Flowlog`
4. Release filter: latest release (default).
5. APK filter / regex: `flowlog-release\.apk`
6. Save and install.

Obtainium will notify you when a new GitHub Release is published.

> **Note:** CI builds are currently signed with the debug keystore so they install easily for testing. For Play Store distribution you would add a proper release keystore.

## Linux (Flatpak)

Flowlog is published as a Flatpak for **x86_64** desktops and **aarch64** Linux phones
(PostmarketOS, Mobian, etc.). It is not on Flathub; install from the project's GitHub
Pages remote or from release bundles.

### Install from remote (recommended)

One-time setup:

```bash
flatpak remote-add --if-not-exists --user flowlog \
  https://isyourbrainfoss.github.io/Flowlog/flowlog.flatpakrepo
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