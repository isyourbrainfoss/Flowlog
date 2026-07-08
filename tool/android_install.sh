#!/usr/bin/env bash
# Find/remove ghost Flowlog installs and sideload the latest GitHub release APK.
set -euo pipefail

PACKAGE=com.flowlog.flowlog
RELEASE_URL="${FLOWLOG_APK_URL:-https://raw.githubusercontent.com/isyourbrainfoss/Flowlog/gh-pages/flowlog-arm64-v8a.apk}"
APK_PATH="${FLOWLOG_APK_PATH:-/tmp/flowlog-release.apk}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools." >&2
  exit 1
fi

devices="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
if [[ -z "$devices" ]]; then
  echo "No adb device found. Enable USB debugging and authorize this computer." >&2
  adb devices
  exit 1
fi

echo "== Installed Flowlog packages =="
adb shell pm list packages -f | rg 'flowlog' || echo "(none)"

echo
echo "== Uninstalling ${PACKAGE} for all users =="
for user in $(adb shell pm list users | rg -o 'UserInfo{[0-9]+:' | rg -o '[0-9]+'); do
  adb shell pm uninstall --user "$user" "$PACKAGE" 2>/dev/null || true
done
adb uninstall "$PACKAGE" 2>/dev/null || true

echo
echo "== Remaining flowlog packages =="
adb shell pm list packages | rg 'flowlog' || echo "(none)"

echo
echo "== Downloading release APK =="
curl -fL --retry 3 --retry-delay 2 -o "$APK_PATH" "$RELEASE_URL"
ls -lh "$APK_PATH"

echo
echo "== Installing =="
if adb install -r "$APK_PATH"; then
  echo "Installed ${PACKAGE} successfully."
else
  echo "Install failed. Common causes:" >&2
  echo "  - Another copy still installed (work profile / second user)" >&2
  echo "  - Incomplete APK download (retry on Wi-Fi)" >&2
  echo "  - Wrong CPU arch (release APK is arm64-only)" >&2
  exit 1
fi