#!/usr/bin/env bash
set -euo pipefail

IPA_FILE="${1:-Zmanim-unsigned.ipa}"

if [ ! -f "$IPA_FILE" ]; then
  echo "Error: IPA file not found at: $IPA_FILE" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Unpacking $IPA_FILE for windowing and multitasking verification..."
unzip -q "$IPA_FILE" -d "$TEMP_DIR"

APP_PATH="$(find "$TEMP_DIR/Payload" -maxdepth 1 -name '*.app' -print -quit)"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Error: No .app bundle found inside Payload directory" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
  echo "Error: Info.plist not found in $APP_PATH" >&2
  exit 1
fi

echo "Inspecting compiled Info.plist: $INFO_PLIST"

# 1. Verify UIRequiresFullScreen is NOT set to true
if /usr/libexec/PlistBuddy -c 'Print :UIRequiresFullScreen' "$INFO_PLIST" 2>/dev/null; then
  REQ_FULL=$(/usr/libexec/PlistBuddy -c 'Print :UIRequiresFullScreen' "$INFO_PLIST")
  if [ "$REQ_FULL" = "true" ] || [ "$REQ_FULL" = "1" ]; then
    echo "FAILED: UIRequiresFullScreen is true, preventing iPad window resizing!" >&2
    exit 1
  fi
  echo "Verified: UIRequiresFullScreen is not true ($REQ_FULL)."
else
  echo "Verified: UIRequiresFullScreen is absent (allows native windowing)."
fi

# 2. Verify UIDesignRequiresCompatibility is NOT set to true
if /usr/libexec/PlistBuddy -c 'Print :UIDesignRequiresCompatibility' "$INFO_PLIST" 2>/dev/null; then
  COMPAT=$(/usr/libexec/PlistBuddy -c 'Print :UIDesignRequiresCompatibility' "$INFO_PLIST")
  if [ "$COMPAT" = "true" ] || [ "$COMPAT" = "1" ]; then
    echo "FAILED: UIDesignRequiresCompatibility is true, forcing legacy compatibility mode!" >&2
    exit 1
  fi
  echo "Verified: UIDesignRequiresCompatibility is not true ($COMPAT)."
else
  echo "Verified: UIDesignRequiresCompatibility is absent."
fi

# 3. Verify TARGETED_DEVICE_FAMILY contains iPad (2)
if /usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$INFO_PLIST" 2>/dev/null; then
  DEVICE_FAMILIES=$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$INFO_PLIST")
  echo "Device families: $DEVICE_FAMILIES"
  if ! echo "$DEVICE_FAMILIES" | grep -q '2'; then
    echo "FAILED: UIDeviceFamily does not include iPad (family 2)!" >&2
    exit 1
  fi
  echo "Verified: iPad device family (2) is supported."
fi

# 4. Verify iPad orientations allow multitasking (both portrait and landscape)
IPAD_ORIENTATIONS=""
if /usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad' "$INFO_PLIST" 2>/dev/null; then
  IPAD_ORIENTATIONS=$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad' "$INFO_PLIST")
elif /usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations' "$INFO_PLIST" 2>/dev/null; then
  IPAD_ORIENTATIONS=$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations' "$INFO_PLIST")
fi

echo "iPad supported orientations: $IPAD_ORIENTATIONS"
if ! echo "$IPAD_ORIENTATIONS" | grep -q 'Portrait'; then
  echo "FAILED: iPad orientations must include Portrait for multitasking" >&2
  exit 1
fi
if ! echo "$IPAD_ORIENTATIONS" | grep -q 'Landscape'; then
  echo "FAILED: iPad orientations must include Landscape for multitasking" >&2
  exit 1
fi
echo "Verified: iPad orientations support multitasking."

echo "All windowing and multitasking checks passed successfully for $IPA_FILE."
