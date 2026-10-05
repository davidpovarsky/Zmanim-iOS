#!/usr/bin/env bash
set -euo pipefail

# verify-ipa-extensions.sh
# Verifies embedded extensions, bundle identifier hierarchy, and configuration in an iOS IPA.

IPA_PATH="${1:-}"

if [ -z "$IPA_PATH" ]; then
    if [ -f "Zmanim-unsigned.ipa" ]; then
        IPA_PATH="Zmanim-unsigned.ipa"
    elif [ -f "build/Zmanim-unsigned.ipa" ]; then
        IPA_PATH="build/Zmanim-unsigned.ipa"
    else
        echo "Error: No IPA path provided and no default IPA found."
        echo "Usage: $0 <path-to-ipa>"
        exit 1
    fi
fi

if [ ! -f "$IPA_PATH" ]; then
    echo "Error: IPA file not found at: $IPA_PATH"
    exit 1
fi

echo "=== Verifying IPA Extensions: $IPA_PATH ==="

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

unzip -q "$IPA_PATH" -d "$WORK_DIR"

APP_PATH="$(find "$WORK_DIR/Payload" -mindepth 1 -maxdepth 1 -name "*.app" -print -quit)"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "FAIL: No .app bundle found in Payload/"
    exit 1
fi

echo "App bundle: $(basename "$APP_PATH")"

# 1. Inspect Main App
MAIN_INFO="$APP_PATH/Info.plist"
if [ ! -f "$MAIN_INFO" ]; then
    echo "FAIL: Main app Info.plist missing"
    exit 1
fi

MAIN_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$MAIN_INFO" 2>/dev/null || true)"
MAIN_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MAIN_INFO" 2>/dev/null || true)"
MAIN_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MAIN_INFO" 2>/dev/null || true)"
MAIN_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$MAIN_INFO" 2>/dev/null || true)"

echo "Main App CFBundleIdentifier: $MAIN_BUNDLE_ID (version $MAIN_VERSION, build $MAIN_BUILD)"
if [ ! -f "$APP_PATH/$MAIN_EXEC" ]; then
    echo "FAIL: Main executable $MAIN_EXEC missing"
    exit 1
fi

# 2. Inspect Widgets Extension
WIDGET_PATH="$APP_PATH/PlugIns/ZmanimWidgets.appex"
if [ ! -d "$WIDGET_PATH" ]; then
    echo "FAIL: ZmanimWidgets.appex missing from PlugIns/"
    exit 1
fi
echo "Verified ZmanimWidgets.appex exists."

WIDGET_INFO="$WIDGET_PATH/Info.plist"
WIDGET_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WIDGET_INFO" 2>/dev/null || true)"
WIDGET_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$WIDGET_INFO" 2>/dev/null || true)"
WIDGET_EXT_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$WIDGET_INFO" 2>/dev/null || true)"
WIDGET_WANTS_LOC="$(/usr/libexec/PlistBuddy -c 'Print :NSWidgetWantsLocation' "$WIDGET_INFO" 2>/dev/null || true)"

echo "Widget Bundle ID: $WIDGET_BUNDLE_ID"
echo "Widget Extension Point: $WIDGET_EXT_POINT"
echo "Widget NSWidgetWantsLocation: $WIDGET_WANTS_LOC"

if [ "$WIDGET_EXT_POINT" != "com.apple.widgetkit-extension" ]; then
    echo "FAIL: ZmanimWidgets NSExtensionPointIdentifier is not com.apple.widgetkit-extension (found: $WIDGET_EXT_POINT)"
    exit 1
fi

if [ ! -f "$WIDGET_PATH/$WIDGET_EXEC" ]; then
    echo "FAIL: Widget executable $WIDGET_EXEC missing"
    exit 1
fi

# 3. Inspect Notification Content Extension
NC_PATH="$APP_PATH/PlugIns/ZmanimNotificationContent.appex"
if [ ! -d "$NC_PATH" ]; then
    echo "FAIL: ZmanimNotificationContent.appex missing from PlugIns/"
    exit 1
fi
echo "Verified ZmanimNotificationContent.appex exists."

NC_INFO="$NC_PATH/Info.plist"
NC_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NC_INFO" 2>/dev/null || true)"
NC_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$NC_INFO" 2>/dev/null || true)"
NC_EXT_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$NC_INFO" 2>/dev/null || true)"
NC_STORYBOARD="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionMainStoryboard' "$NC_INFO" 2>/dev/null || true)"

echo "Notification Content Bundle ID: $NC_BUNDLE_ID"
echo "Notification Content Extension Point: $NC_EXT_POINT"
echo "Notification Content Storyboard: $NC_STORYBOARD"

if [ "$NC_EXT_POINT" != "com.apple.usernotifications.content-extension" ]; then
    echo "FAIL: NotificationContent NSExtensionPointIdentifier is not com.apple.usernotifications.content-extension (found: $NC_EXT_POINT)"
    exit 1
fi

if [ ! -f "$NC_PATH/$NC_EXEC" ]; then
    echo "FAIL: NotificationContent executable $NC_EXEC missing"
    exit 1
fi

# Check storyboard compiled resource
if [ ! -d "$NC_PATH/$NC_STORYBOARD.storyboardc" ] && [ ! -f "$NC_PATH/$NC_STORYBOARD.storyboardc" ]; then
    echo "FAIL: Compiled storyboard $NC_STORYBOARD.storyboardc missing in $NC_PATH"
    exit 1
fi
echo "Verified compiled storyboard $NC_STORYBOARD.storyboardc exists."

# 4. Check Category in Notification Content Info.plist
NC_CAT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:UNNotificationExtensionCategory' "$NC_INFO" 2>/dev/null || true)"
echo "Notification Content Category: $NC_CAT"
if ! echo "$NC_CAT" | grep -q "ZMANIM_ALERT"; then
    echo "FAIL: UNNotificationExtensionCategory does not contain ZMANIM_ALERT"
    exit 1
fi

# 5. Validate Bundle Identifier Hierarchy
echo "--- Checking Bundle Identifier Hierarchy ---"
if [[ "$WIDGET_BUNDLE_ID" != "$MAIN_BUNDLE_ID."* ]]; then
    echo "CRITICAL SIDELOAD WARNING / FAILURE:"
    echo "Widget bundle ID ($WIDGET_BUNDLE_ID) is NOT a valid child of the main bundle ID ($MAIN_BUNDLE_ID)!"
    echo "When sideloading, if the signing tool modifies the main bundle identifier but does not rename embedded app extensions to match (<mainID>.<extensionID>), iOS security policy strictly rejects the extension at runtime."
    exit 1
fi

if [[ "$NC_BUNDLE_ID" != "$MAIN_BUNDLE_ID."* ]]; then
    echo "CRITICAL SIDELOAD WARNING / FAILURE:"
    echo "Notification Content bundle ID ($NC_BUNDLE_ID) is NOT a valid child of the main bundle ID ($MAIN_BUNDLE_ID)!"
    echo "When sideloading, if the signing tool modifies the main bundle identifier but does not rename embedded app extensions to match (<mainID>.<extensionID>), iOS security policy strictly rejects the extension at runtime."
    exit 1
fi
echo "PASSED: Both extension bundle IDs are valid hierarchical children of $MAIN_BUNDLE_ID"

# 6. Check Provisioning Profiles if present
echo "--- Checking Provisioning Profiles ---"
if [ -f "$APP_PATH/embedded.mobileprovision" ]; then
    echo "Main app contains embedded.mobileprovision"
fi
if [ -f "$WIDGET_PATH/embedded.mobileprovision" ]; then
    echo "Widget contains embedded.mobileprovision"
fi
if [ -f "$NC_PATH/embedded.mobileprovision" ]; then
    echo "Notification Content contains embedded.mobileprovision"
fi

# 7. Check Entitlements / Codesign if signed
echo "--- Checking Code Signing & Entitlements ---"
if command -v codesign >/dev/null 2>&1; then
    if codesign -v "$APP_PATH" 2>/dev/null; then
        echo "Main app is signed. Entitlements:"
        codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true
        echo "Widget entitlements:"
        codesign -d --entitlements :- "$WIDGET_PATH" 2>/dev/null || true
    else
        echo "App is unsigned (expected for unsigned CI release artifact)."
    fi
fi

echo "=== All IPA extension checks PASSED successfully! ==="
exit 0
