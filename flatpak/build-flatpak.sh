#!/usr/bin/env bash
# Build a Navigation Flatpak for the current (or requested) CPU architecture.
#
# Produces:
#   - ostree repo at $REPO_DIR (default: flatpak/repo) for hosting under gh-pages/repo
#   - single-file bundle flatpak/com.isyourbrainfoss.Navigation-${ARCH}.flatpak
#
# Usage:
#   ./flatpak/build-flatpak.sh [x86_64|aarch64]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLATPAK_DIR="$ROOT/flatpak"
APP_DIR="$ROOT"
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

echo "==> Ensuring GNOME Platform/SDK 48"
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak install -y --user flathub org.gnome.Platform//48 org.gnome.Sdk//48 >/dev/null 2>&1 || \
  flatpak install -y flathub org.gnome.Platform//48 org.gnome.Sdk//48

echo "==> Building Flutter Linux release ($FLATPAK_ARCH)"
cd "$APP_DIR"
flutter pub get
flutter build linux --release

BUNDLE="$APP_DIR/build/linux/$FLUTTER_OUT/release/bundle"
if [[ ! -x "$BUNDLE/navigation" ]]; then
  echo "Missing Linux bundle at $BUNDLE" >&2
  exit 1
fi

# Launcher icons live in flatpak/icons/hicolor (regenerate with tool/generate_icons.sh).

echo "==> Packaging Flutter bundle archive"
tar -czf "$FLATPAK_DIR/navigation-linux-bundle.tar.gz" -C "$BUNDLE" .

REPO_DIR="${REPO_DIR:-$FLATPAK_DIR/repo}"
mkdir -p "$REPO_DIR"
BUILD_DIR="${BUILD_DIR:-$FLATPAK_DIR/build-$FLATPAK_ARCH}"
rm -rf "$BUILD_DIR"

echo "==> flatpak-builder ($FLATPAK_ARCH) → $REPO_DIR"
flatpak-builder \
  --user \
  --arch="$FLATPAK_ARCH" \
  --force-clean \
  --repo="$REPO_DIR" \
  "$BUILD_DIR" \
  "$FLATPAK_DIR/com.isyourbrainfoss.Navigation.yml"

BUNDLE_OUT="$FLATPAK_DIR/com.isyourbrainfoss.Navigation-${FLATPAK_ARCH}.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_OUT" com.isyourbrainfoss.Navigation \
  --arch="$FLATPAK_ARCH" \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo

cp "$FLATPAK_DIR/navigation.flatpakrepo" "$ROOT/navigation.flatpakrepo" 2>/dev/null || true

echo
echo "==> Built:"
echo "    Repo:   $REPO_DIR"
echo "    Bundle: $BUNDLE_OUT"
echo "    Remote: $FLATPAK_DIR/navigation.flatpakrepo"
echo
echo "Add as a user remote (after publishing to gh-pages):"
echo "  flatpak remote-add --if-not-exists --user navigation \\"
echo "    https://isyourbrainfoss.github.io/navigation/navigation.flatpakrepo"
echo "  flatpak install --user navigation com.isyourbrainfoss.Navigation"
