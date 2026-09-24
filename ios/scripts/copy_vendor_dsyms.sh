#!/bin/sh
# Copy vendor dSYMs (or generate UUID-matching ones) into the archive.
# CocoaPods embeds prebuilt Razorpay / ScreenPreventerKit binaries but does not
# copy their dSYMs, which causes App Store "Upload Symbols Failed" warnings.
set -euo pipefail

case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *) exit 0 ;;
esac

if [ "${PLATFORM_NAME:-}" = "iphonesimulator" ]; then
  exit 0
fi

APP_FRAMEWORKS="${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}"
DSYM_DIR="${DWARF_DSYM_FOLDER_PATH:-}"
PODS_ROOT="${PODS_ROOT:-}"

if [ ! -d "$APP_FRAMEWORKS" ] || [ -z "$DSYM_DIR" ]; then
  exit 0
fi

mkdir -p "$DSYM_DIR"

uuid_of() {
  dwarfdump -u "$1" 2>/dev/null | awk '/UUID:/ { print $2; exit }'
}

for framework in "$APP_FRAMEWORKS"/*.framework; do
  [ -d "$framework" ] || continue
  name="$(basename "$framework" .framework)"
  binary="${framework}/${name}"
  [ -f "$binary" ] || continue

  dest="${DSYM_DIR}/${name}.framework.dSYM"
  bin_uuid="$(uuid_of "$binary")"
  [ -n "$bin_uuid" ] || continue

  if [ -d "$dest" ]; then
    existing_uuid="$(uuid_of "$dest")"
    if [ "$existing_uuid" = "$bin_uuid" ]; then
      continue
    fi
    rm -rf "$dest"
  fi

  vendor=""
  if [ -n "$PODS_ROOT" ] && [ -d "$PODS_ROOT" ]; then
    vendor="$(find "$PODS_ROOT" -path "*/ios-arm64/dSYMs/${name}.framework.dSYM" -type d 2>/dev/null | head -n 1 || true)"
  fi

  if [ -n "$vendor" ] && [ -d "$vendor" ]; then
    vendor_uuid="$(uuid_of "$vendor")"
    if [ "$vendor_uuid" = "$bin_uuid" ]; then
      cp -R "$vendor" "$dest"
      echo "Copied vendor dSYM for ${name} (${bin_uuid})"
      continue
    fi
  fi

  echo "Generating dSYM for ${name} (${bin_uuid})"
  xcrun dsymutil "$binary" -o "$dest"
done
