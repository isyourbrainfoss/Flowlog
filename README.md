# Flowlog

Personal coffee intelligence hub — live shot curves, history, bean library, and sensor tooling.

## Android testing

### USB (best for development)

USB debugging is the preferred way while you are actively developing:

1. On your phone: **Settings → Developer options → USB debugging** (enable).
2. Connect via USB and confirm the debugging prompt on the phone.
3. From this repo:

```bash
cd app/flowlog
flutter pub get
flutter devices          # confirm your phone is listed
flutter run              # debug build with hot reload
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