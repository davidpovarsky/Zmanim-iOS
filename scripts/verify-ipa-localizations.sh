#!/usr/bin/env bash
set -euo pipefail

# verify-ipa-localizations.sh
# Verifies end-to-end localization resources, Info.plist configurations, and string contents in an iOS IPA.

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

echo "=== Verifying IPA Localizations: $IPA_PATH ==="

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

unzip -q "$IPA_PATH" -d "$WORK_DIR"

APP_PATH="$(find "$WORK_DIR/Payload" -mindepth 1 -maxdepth 1 -name "*.app" -print -quit)"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "FAIL: No .app bundle found in Payload/"
    exit 1
fi

echo "App bundle: $(basename "$APP_PATH")"

ERRORS=0

fail() {
    echo "FAIL: $1" >&2
    ERRORS=$((ERRORS + 1))
}

pass() {
    echo "PASS: $1"
}

# --- 1. Main App Info.plist Checks ---
MAIN_INFO="$APP_PATH/Info.plist"
if [ ! -f "$MAIN_INFO" ]; then
    fail "Main app Info.plist missing"
else
    DEV_LANG="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$MAIN_INFO" 2>/dev/null || true)"
    if [ "$DEV_LANG" = "he" ]; then
        pass "Main app CFBundleDevelopmentRegion is 'he'"
    else
        fail "Main app CFBundleDevelopmentRegion is '$DEV_LANG', expected 'he'"
    fi

    LOCALIZATIONS="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleLocalizations' "$MAIN_INFO" 2>/dev/null || true)"
    if echo "$LOCALIZATIONS" | grep -q "he" && echo "$LOCALIZATIONS" | grep -q "en"; then
        pass "Main app CFBundleLocalizations contains both 'he' and 'en'"
    else
        fail "Main app CFBundleLocalizations missing 'he' or 'en' (found: $LOCALIZATIONS)"
    fi
fi

# --- 2. Main App Localization Files Presence & Linting ---
REQUIRED_FILES=(
    "he.lproj/Localizable.strings"
    "en.lproj/Localizable.strings"
    "he.lproj/InfoPlist.strings"
    "en.lproj/InfoPlist.strings"
)

for file in "${REQUIRED_FILES[@]}"; do
    TARGET_FILE="$APP_PATH/$file"
    if [ -f "$TARGET_FILE" ]; then
        pass "Found $file in main app"
        if plutil -lint "$TARGET_FILE" >/dev/null 2>&1; then
            pass "Syntax valid: $file"
        else
            fail "Syntax error in $file (failed plutil -lint)"
        fi
    else
        fail "Missing required file in main app: $file"
    fi
done

# --- 3. Key Translations in Main App ---
HE_INFO_STRINGS="$APP_PATH/he.lproj/InfoPlist.strings"
EN_INFO_STRINGS="$APP_PATH/en.lproj/InfoPlist.strings"
HE_APP_STRINGS="$APP_PATH/he.lproj/Localizable.strings"
EN_APP_STRINGS="$APP_PATH/en.lproj/Localizable.strings"

if [ -f "$HE_INFO_STRINGS" ]; then
    if grep -q "זמנים" "$HE_INFO_STRINGS"; then
        pass "he InfoPlist.strings contains Hebrew app name"
    else
        fail "he InfoPlist.strings missing Hebrew app name 'זמנים'"
    fi
    if grep -q "NSLocationWhenInUseUsageDescription" "$HE_INFO_STRINGS"; then
        pass "he InfoPlist.strings contains NSLocationWhenInUseUsageDescription"
    else
        fail "he InfoPlist.strings missing NSLocationWhenInUseUsageDescription"
    fi
fi

if [ -f "$EN_INFO_STRINGS" ]; then
    if grep -q "Zmanim" "$EN_INFO_STRINGS"; then
        pass "en InfoPlist.strings contains English app name 'Zmanim'"
    else
        fail "en InfoPlist.strings missing English app name 'Zmanim'"
    fi
    if grep -q "NSLocationWhenInUseUsageDescription" "$EN_INFO_STRINGS"; then
        pass "en InfoPlist.strings contains NSLocationWhenInUseUsageDescription"
    else
        fail "en InfoPlist.strings missing NSLocationWhenInUseUsageDescription"
    fi
fi

if [ -f "$HE_APP_STRINGS" ]; then
    if grep -q '"app_name" = "זמנים"' "$HE_APP_STRINGS" || grep -q 'app_name.*=.*זמנים' "$HE_APP_STRINGS"; then
        pass "he Localizable.strings has app_name = 'זמנים'"
    else
        fail "he Localizable.strings missing app_name = 'זמנים'"
    fi
    if grep -q 'נתוני מזג אוויר: MET Norway' "$HE_APP_STRINGS"; then
        pass "he Localizable.strings has localized weather attribution"
    else
        fail "he Localizable.strings missing localized weather attribution"
    fi
fi

if [ -f "$EN_APP_STRINGS" ]; then
    if grep -q '"app_name" = "Zmanim"' "$EN_APP_STRINGS" || grep -q 'app_name.*=.*Zmanim' "$EN_APP_STRINGS"; then
        pass "en Localizable.strings has app_name = 'Zmanim'"
    else
        fail "en Localizable.strings missing app_name = 'Zmanim'"
    fi
    if grep -q 'Weather data: MET Norway' "$EN_APP_STRINGS"; then
        pass "en Localizable.strings has English weather attribution"
    else
        fail "en Localizable.strings missing English weather attribution"
    fi
fi

# --- 4. Package Bundles (OneBusAwayWeatherCore & OneBusAwayWeatherUI) ---
CORE_BUNDLES=$(find "$APP_PATH" -name "*WeatherCore*.bundle" || true)
UI_BUNDLES=$(find "$APP_PATH" -name "*WeatherUI*.bundle" || true)

if [ -z "$CORE_BUNDLES" ]; then
    fail "No OneBusAwayWeatherCore bundle found in app"
else
    for bundle in $CORE_BUNDLES; do
        pass "Inspecting Core bundle: $(basename "$bundle")"
        if [ -d "$bundle/he.lproj" ] && [ -d "$bundle/en.lproj" ]; then
            pass "Core bundle has he.lproj and en.lproj"
        else
            fail "Core bundle $(basename "$bundle") missing he.lproj or en.lproj"
        fi
        for strfile in $(find "$bundle" -name "*.strings"); do
            if plutil -lint "$strfile" >/dev/null 2>&1; then
                pass "Syntax valid: $strfile"
            else
                fail "Syntax error in $strfile"
            fi
        done
        if [ -f "$bundle/he.lproj/Localizable.strings" ]; then
            if grep -q "עכשיו" "$bundle/he.lproj/Localizable.strings"; then
                pass "Core he Localizable.strings contains 'עכשיו'"
            else
                fail "Core he Localizable.strings missing 'עכשיו'"
            fi
        fi
    done
fi

if [ -z "$UI_BUNDLES" ]; then
    fail "No OneBusAwayWeatherUI bundle found in app"
else
    for bundle in $UI_BUNDLES; do
        pass "Inspecting UI bundle: $(basename "$bundle")"
        if [ -d "$bundle/he.lproj" ] && [ -d "$bundle/en.lproj" ]; then
            pass "UI bundle has he.lproj and en.lproj"
        else
            fail "UI bundle $(basename "$bundle") missing he.lproj or en.lproj"
        fi
        for strfile in $(find "$bundle" -name "*.strings"); do
            if plutil -lint "$strfile" >/dev/null 2>&1; then
                pass "Syntax valid: $strfile"
            else
                fail "Syntax error in $strfile"
            fi
        done
    done
fi

# --- 5. Extensions (Widgets & Notification Content) ---
check_extension_localizations() {
    local ext_path="$1"
    local ext_name
    ext_name="$(basename "$ext_path")"

    if [ ! -d "$ext_path" ]; then
        fail "Extension missing: $ext_name"
        return
    fi

    echo "--- Checking Extension: $ext_name ---"
    local ext_info="$ext_path/Info.plist"
    if [ -f "$ext_info" ]; then
        local ext_dev_lang
        ext_dev_lang="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$ext_info" 2>/dev/null || true)"
        if [ "$ext_dev_lang" = "he" ]; then
            pass "$ext_name CFBundleDevelopmentRegion is 'he'"
        else
            fail "$ext_name CFBundleDevelopmentRegion is '$ext_dev_lang', expected 'he'"
        fi

        local ext_locs
        ext_locs="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleLocalizations' "$ext_info" 2>/dev/null || true)"
        if echo "$ext_locs" | grep -q "he" && echo "$ext_locs" | grep -q "en"; then
            pass "$ext_name CFBundleLocalizations contains 'he' and 'en'"
        else
            fail "$ext_name CFBundleLocalizations missing 'he' or 'en'"
        fi
    fi

    if [ -d "$ext_path/he.lproj" ] && [ -d "$ext_path/en.lproj" ]; then
        pass "$ext_name contains he.lproj and en.lproj"
    else
        fail "$ext_name missing he.lproj or en.lproj"
    fi

    for strfile in $(find "$ext_path" -name "*.strings"); do
        if plutil -lint "$strfile" >/dev/null 2>&1; then
            pass "Syntax valid: $strfile"
        else
            fail "Syntax error in $strfile"
        fi
    done
}

WIDGET_EXT="$APP_PATH/PlugIns/ZmanimWidgets.appex"
NC_EXT="$APP_PATH/PlugIns/ZmanimNotificationContent.appex"

check_extension_localizations "$WIDGET_EXT"
check_extension_localizations "$NC_EXT"

# --- Summary ---
echo "=========================================="
if [ "$ERRORS" -eq 0 ]; then
    echo "SUCCESS: All IPA localization checks passed!"
    exit 0
else
    echo "ERROR: IPA localization verification failed with $ERRORS error(s)."
    exit 1
fi
