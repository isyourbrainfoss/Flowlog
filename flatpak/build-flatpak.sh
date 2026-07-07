#!/usr/bin/env bash
# Build a Flowlog Flatpak for the current (or requested) CPU architecture.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLATPAK_DIR="$ROOT/flatpak"
APP_DIR="$ROOT/app/flowlog"
ARCH="${1:-$(uname -m)}"

case "$ARCH" in
  x86_64|amd64)
    FLATPAK_ARCH=x86_64
    FLUTTER_OUT=x64
    ;;
  aarch64|arm64)
    FLATPAK_ARCH=aarch64
    FLUTTER_OUT=arm64
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

if ! command -v flatpak-builder >/dev/null; then
  echo "flatpak-builder is required." >&2
  exit 1
fi

if ! command -v flutter >/dev/null; then
  echo "flutter is required." >&2
  exit 1
fi

echo "==> Installing GNOME Platform 48 (if missing)"
flatpak install -y --user flathub org.gnome.Platform//48 org.gnome.Sdk//48 >/dev/null 2>&1 || \
  flatpak install -y flathub org.gnome.Platform//48 org.gnome.Sdk//48

echo "==> Building Flutter Linux release ($FLATPAK_ARCH)"
cd "$APP_DIR"
flutter pub get
flutter build linux --release

BUNDLE="$APP_DIR/build/linux/$FLUTTER_OUT/release/bundle"
if [[ ! -f "$BUNDLE/flowlog" ]]; then
  echo "Missing Linux bundle at $BUNDLE" >&2
  exit 1
fi

ICON_SRC="$APP_DIR/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
ICON_DST="$FLATPAK_DIR/com.flowlog.flowlog.png"
cp "$ICON_SRC" "$ICON_DST"

echo "==> Packaging Flatpak bundle"
tar -czf "$FLATPAK_DIR/flowlog-linux-bundle.tar.gz" -C "$BUNDLE" .

REPO_DIR="${REPO_DIR:-$FLATPAK_DIR/repo}"
mkdir -p "$REPO_DIR"
BUILD_DIR="${BUILD_DIR:-$FLATPAK_DIR/build-$FLATPAK_ARCH}"
rm -rf "$BUILD_DIR"

flatpak-builder \
  --user \
  --arch="$FLATPAK_ARCH" \
  --force-clean \
  --repo="$REPO_DIR" \
  "$BUILD_DIR" \
  "$FLATPAK_DIR/com.flowlog.flowlog.yml"

BUNDLE_OUT="$FLATPAK_DIR/com.flowlog.flowlog-${FLATPAK_ARCH}.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_OUT" com.flowlog.flowlog \
  --arch="$FLATPAK_ARCH"

echo "==> Built:"
echo "    Repo:   $REPO_DIR"
echo "    Bundle: $BUNDLE_OUT"
echo
echo "Install locally:"
echo "  flatpak install --user --bundle $BUNDLE_OUT"
echo
echo "Or from the local repo:"
echo "  flatpak --user remote-add --if-not-exists --no-gpg-verify flowlog-local file://$REPO_DIR"
echo "  flatpak install --user flowlog-local com.flowlog.flowlog"