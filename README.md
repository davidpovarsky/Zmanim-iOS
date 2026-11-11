# Zmanim iOS

Modern native iOS zmanim app with a live solar horizon, Hebcal-backed times, location-aware calculations, configurable reminders, rich notifications, interactive Home/Lock Screen widgets, Live Activities and Dynamic Island.

## Architecture
- **App**: SwiftUI home (`HomeView`, `HomeHeader`, `NextZmanCard`, `ZmanimDayList`, `SolarHero`) + notification settings + weather popup.
- **Shared**: models, design system, App Group cache, App Intents (`WidgetPagingIntents`, `ToggleQuickReminderIntent`, `OpenZmanimIntent`), `WidgetDaySelector`, `WidgetPageReducer`, `WidgetPageStateStore`, `NextZmanResolver`, `ZmanDayResolver`.
- **Weather (`Packages/OneBusAwayWeather`, `Features/Weather`)**: Port of the authoritative OneBusAway Israel weather component (`OneBusAwayWeatherCore`, `OneBusAwayWeatherUI`), MET Norway Locationforecast 2.0 compact client (`METNorwayWeatherClient`), HTTP caching (`WeatherCache`), display adapter (`ZmanimWeatherDisplayAdapter`), interactive header button, and native popup (`WeatherDetailPopup`).
- **Widgets**: small/medium/large/extra-large, Lock Screen accessories, Live Activity.
- **Notification Content Extension**: expanded rich alert UI (`NotificationViewController`).
- **Services**: Core Location, Hebcal, notification scheduling.

The Xcode project is generated deterministically from `project.yml` using XcodeGen.

## Weather Integration & Offline / No-Fake Policy
- **Source**: Norwegian Meteorological Institute (MET Norway) Locationforecast 2.0 compact API. Data licensed under CC BY 4.0 with visible in-app attribution.
- **Strict No-Fake Policy**: If no genuine forecast data is available (offline start or network failure) and no valid cache exists, no weather descriptions, temperatures, or icons are displayed. The UI displays the location name only over `Color.zmanBackground`, leaving all zmanim and solar calculations fully functional.
- **Weather Detail Popup**: Tapping the top-left location/weather indicator on the Home screen opens an interactive native modal displaying rolling 24-hour hourly temperatures and symbols, wind speed (km/h), chance of precipitation (when available from MET), 24h high/low, and source attribution.

## Interactive Widget Paging & 60-Second Reversion
- **5-Item Day Partitioning**: `systemLarge` and `systemExtraLarge` widgets partition the current day's zmanim into stable pages of 5 items using `WidgetDaySelector`.
- **App Intents**: Paging is driven interactively by `NextWidgetPageIntent` and `PreviousWidgetPageIntent` (`openAppWhenRun = false`) without opening the host application.
- **60-Second Reversion (Best Effort)**: Each tap records `expiresAt = now + 60s` in the shared App Group. The timeline provider schedules a reversion entry back to page 0 at `expiresAt`. Note that per Apple WidgetKit scheduling policies, the exact timing of the visual reset is best-effort and subject to system budget and power management. Midnight rollovers and city changes immediately reset paging to page 0.

## End-of-Day Next Zman & Midnight Rollover
- **Next Zman Resolution**: When all zmanim for the current day have passed, `NextZmanResolver` retrieves the earliest upcoming zman (e.g. tomorrow's Alot HaShachar) from pre-loaded Hebcal multi-day data and displays it with a "מחר" badge, completely eliminating false "loading" states.
- **Day Transitions**: Day rollover is calculated using the active city's time zone, updating sunrise, sunset, the solar arc, Hebrew date headers, and daily lists synchronously.

## Build & CI
Every push runs the macOS GitHub Actions workflow (`.github/workflows/build-unsigned-ipa.yml`), generates the Xcode project with XcodeGen, executes unit and UI test suites on an iOS Simulator, captures authentic widget and weather diagnostics, packages `Payload/Zmanim.app` as `Zmanim-unsigned.ipa`, and verifies embedded extension points and bundle identifiers.
