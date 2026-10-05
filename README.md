# Zmanim iOS

Modern native iOS zmanim app with a live solar horizon, Hebcal-backed times, location-aware calculations, configurable reminders, rich notifications, interactive Home/Lock Screen widgets, Live Activities and Dynamic Island.

## Architecture
- App: SwiftUI home + notification settings
- Shared: models, design system, App Group cache, App Intents, Activity attributes
- Widgets: small/medium/large/extra-large, Lock Screen accessories, Live Activity
- Notification Content Extension: expanded rich alert UI
- Services: Core Location, Hebcal, notification scheduling

The Xcode project is generated deterministically from project.yml using XcodeGen.

## Build
Every push to main runs the macOS GitHub Actions workflow, generates the Xcode project, builds all targets without signing, packages Payload/Zmanim.app as Zmanim-unsigned.ipa, and uploads it as an Actions artifact.

The unsigned IPA is intended for sideload signing. Production signing must provision the App Group and Live Activities capabilities.

## Data
Zmanim are retrieved from Hebcal for either the device location or a fixed city. The app caches the current-day snapshot in the shared App Group for widgets.
