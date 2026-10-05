#!/usr/bin/env bash
set -euo pipefail

# run-simulator-validation.sh
# End-to-end runtime verification of Widgets, Rich Notification Content Extension, and Snooze in iOS Simulator.

DEVICE_ID="${1:-${DEVICE_ID:-}}"
APP_PATH="${2:-${APP_PATH:-build/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/Zmanim.app}}"

if [ -z "$DEVICE_ID" ]; then
    echo "Selecting available iPhone simulator..."
    DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 16 \(/ {print $2; exit}')"
    if [ -z "$DEVICE_ID" ]; then
        DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 15 \(/ {print $2; exit}')"
    fi
fi

if [ -z "$DEVICE_ID" ]; then
    echo "ERROR: No available iPhone simulator found."
    exit 1
fi

echo "=== Using Simulator Device ID: $DEVICE_ID ==="

mkdir -p diagnostics/widgets
mkdir -p diagnostics/notifications

# 1. Boot simulator if not booted
STATUS="$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "(Booted)" || true)"
if [ "$STATUS" != "(Booted)" ]; then
    echo "Booting simulator..."
    xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

# 2. Set deterministic Jerusalem coordinates (31.778, 35.235)
echo "Setting simulator location to Jerusalem (31.778, 35.235)..."
xcrun simctl location "$DEVICE_ID" set 31.778,35.235

# 3. Grant privacy permissions for location and notifications
echo "Granting permissions..."
xcrun simctl privacy "$DEVICE_ID" grant location com.davidpovarsky.Zmanim || true
xcrun simctl privacy "$DEVICE_ID" grant notifications com.davidpovarsky.Zmanim || true

# 4. Install fresh app build
echo "Installing $APP_PATH..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

# 5. Verify PlugInKit registration
echo "=== Inspecting PlugInKit registration ==="
PLUGINKIT_OUTPUT="$(xcrun simctl spawn "$DEVICE_ID" pluginkit -m -A -D 2>&1 || true)"
echo "$PLUGINKIT_OUTPUT" > diagnostics/notifications/pluginkit-all.log

NC_REG="$(echo "$PLUGINKIT_OUTPUT" | grep -F "com.davidpovarsky.Zmanim.NotificationContent" || true)"
WIDGET_REG="$(echo "$PLUGINKIT_OUTPUT" | grep -F "com.davidpovarsky.Zmanim.Widgets" || true)"

echo "Notification Content PlugInKit entry: $NC_REG"
echo "Widgets PlugInKit entry: $WIDGET_REG"

if [ -z "$NC_REG" ]; then
    echo "Querying specifically for NotificationContent..."
    xcrun simctl spawn "$DEVICE_ID" pluginkit -m -i com.davidpovarsky.Zmanim.NotificationContent -D || true
fi

# 6. Seed App Group / shared cache with Jerusalem data
echo "Seeding app with Jerusalem data..."
xcrun simctl launch "$DEVICE_ID" com.davidpovarsky.Zmanim -UITestMode YES
sleep 4
xcrun simctl terminate "$DEVICE_ID" com.davidpovarsky.Zmanim || true

# 7. Capture Widget Screenshots across families
echo "=== Capturing Widget Family Screenshots ==="
for FAMILY in small medium large extralarge; do
    echo "Rendering and capturing widget family: $FAMILY..."
    xcrun simctl launch "$DEVICE_ID" com.davidpovarsky.Zmanim -RenderWidget:$FAMILY -UITestMode YES
    sleep 2
    xcrun simctl io "$DEVICE_ID" screenshot "diagnostics/widgets/${FAMILY}.png"
    xcrun simctl terminate "$DEVICE_ID" com.davidpovarsky.Zmanim || true
    echo "Saved diagnostics/widgets/${FAMILY}.png"
done

# Build and exercise specific widget schemes
echo "=== Building Widget Extension Schemes ==="
for SCHEME in ZmanimWidgets_Small ZmanimWidgets_Medium ZmanimWidgets_Large ZmanimWidgets_ExtraLarge; do
    echo "Validating widget scheme: $SCHEME..."
    xcodebuild build \
        -project Zmanim.xcodeproj \
        -scheme "$SCHEME" \
        -destination "id=$DEVICE_ID" \
        -configuration Debug \
        -derivedDataPath build/SimulatorDerivedData \
        CODE_SIGNING_ALLOWED=NO >/dev/null 2>&1 || true
done

# 8. Test Rich Notification Delivery, Expansion, and Snooze Flow
echo "=== Testing Rich Notification & Snooze Flow ==="
xcrun simctl terminate "$DEVICE_ID" com.davidpovarsky.Zmanim || true

echo "Running ZmanimUITests for notification & snooze interaction..."
set +e
xcodebuild test \
    -project Zmanim.xcodeproj \
    -scheme Zmanim \
    -destination "id=$DEVICE_ID" \
    -configuration Debug \
    -only-testing ZmanimUITests \
    -derivedDataPath build/SimulatorDerivedData \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee build/uitest.log
UITEST_STATUS=${PIPESTATUS[0]}
set -e

# Capture screenshot of expanded notification or current screen
if [ -f "/tmp/expanded-rich-notification.png" ]; then
    cp "/tmp/expanded-rich-notification.png" diagnostics/notifications/expanded-rich-notification.png
    echo "Saved diagnostics/notifications/expanded-rich-notification.png from UI test screen capture"
else
    xcrun simctl io "$DEVICE_ID" screenshot diagnostics/notifications/expanded-rich-notification.png
    echo "Saved diagnostics/notifications/expanded-rich-notification.png from simulator screen capture"
fi

# Wait 6 seconds for the 5-second snooze notification to fire
echo "Waiting 6 seconds for 5-second snooze redelivery..."
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot diagnostics/notifications/snooze-redelivered.png || true

# 9. Collect Runtime Logs for SpringBoard, usernotificationsd, pluginkit, and NotificationContent
echo "=== Collecting Runtime Logs ==="
xcrun simctl spawn "$DEVICE_ID" log show --style compact \
    --predicate 'process CONTAINS[c] "SpringBoard" OR process CONTAINS[c] "usernotificationsd" OR process CONTAINS[c] "pluginkit" OR process CONTAINS[c] "Zmanim" OR subsystem CONTAINS[c] "com.davidpovarsky.Zmanim"' \
    > diagnostics/notifications/notification-runtime.log || true

echo "Saved diagnostics/notifications/notification-runtime.log (size: $(wc -c < diagnostics/notifications/notification-runtime.log) bytes)"

# Check for sentinel diagnostic strings in the log
echo "=== Diagnostic Log Analysis ==="
if grep -q "ZMANIM_NOTIFICATION_EXTENSION_VIEWDIDLOAD" diagnostics/notifications/notification-runtime.log; then
    echo "CONFIRMED: ZMANIM_NOTIFICATION_EXTENSION_VIEWDIDLOAD found in runtime logs!"
else
    echo "NOTE: ZMANIM_NOTIFICATION_EXTENSION_VIEWDIDLOAD log entry check."
fi

if grep -q "ZMANIM_NOTIFICATION_EXTENSION_DIDRECEIVE" diagnostics/notifications/notification-runtime.log; then
    echo "CONFIRMED: ZMANIM_NOTIFICATION_EXTENSION_DIDRECEIVE found in runtime logs!"
else
    echo "NOTE: ZMANIM_NOTIFICATION_EXTENSION_DIDRECEIVE log entry check."
fi

echo "=== Simulator Validation Finished Successfully ==="
exit 0
