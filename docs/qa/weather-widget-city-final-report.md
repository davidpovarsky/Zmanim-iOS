# Zmanim-iOS — Weather Refresh & Widget City Selection Final QA & Engineering Report

**Date:** 2026-10-21  
**Target Environment:** iPadOS 27, Xcode 26.6 / iOS 26 SDK (iOS 17.0+ compatibility)  
**Branch:** `feature/met-weather-widget-paging-eod`  
**Pull Request:** https://github.com/davidpovarsky/Zmanim-iOS/pull/1  
**Baseline SHA:** `8a096085e69113dd558f914c0b22a51fb8d25f57`

---

## 1. Executive Summary & Root Cause Analysis

Following real hardware testing on iPad with SideStore, two P0 blockers were identified:
1. **P0-WEATHER — Automatic Weather Refresh Failure:** Weather forecast (temperature, description, icon) and `SwiftUISky` background did not refresh automatically when switching cities in `HomeLocationMenu`, requiring an artificial tap on the top manual refresh button.
2. **P0-WIDGET-CITY — Saved City Widget Displaying Empty Data:** In system *Edit Widget* settings, selecting any saved city resulted in `No zmanim data available` or recovery prompt instead of the city's times.

### Detailed Root Causes Found in Code:
- **C1 (SwiftUI Observation Gap):** In `AppModel.swift`, `weatherModel` was declared as `@Published public var weatherModel = WeatherSceneModel()`. Because `WeatherSceneModel` is an `ObservableObject`, changes to its internal properties (`weatherDisplay`, `condition`, `cloudCover`) fired `weatherModel.objectWillChange` but **never triggered parent `AppModel.objectWillChange`**. `HomeView.swift` accessed weather properties through `@EnvironmentObject private var model: AppModel` without directly observing `weatherModel`. Thus, when MET Norway network requests completed, SwiftUI had no direct observation dependency and failed to re-render the header, popup, and backdrop until an unrelated state change occurred.
- **C2 (Serial Coupling with Hebcal):** In `AppModel.selectActiveChoice(.savedCity)`, weather loading was deferred until after `HebcalService.fetchDays(..., count: 8)` finished. When Hebcal took time or had network latency, weather was completely blocked from loading.
- **C3 (Inverted Persistence & WidgetKit Reload Sequence):** In `AppModel.addSavedCity`, `WidgetCenter.shared.reloadAllTimelines()` was called **before** `HebcalService.fetchDays` completed and before `LocationSnapshotStore.saveSnapshot` persisted the city snapshot. When the background fetch completed, no reload was triggered. Consequently, WidgetKit queried for city data when the snapshot was completely absent, cached an empty recovery state, and stopped querying.
- **C4 (Phantom City UUID Generation on Store Failure):** In `LocationPreferencesStore.addCity`, a `try?` block fell back to returning `fallbackCity = SavedCity(id: UUID().uuidString...)` on failure. The app model continued as if the city existed, but the Widget extension had no record of this UUID in its shared store.
- **C5 (Non-Deterministic Migration Hash):** Legacy settings migration computed `stableHash = abs("\(cleanName)_\(resolved.latitude)_\(resolved.longitude)".hashValue)`. In Swift, `String.hashValue` uses SipHash with randomized per-process seeds, producing divergent entity IDs between the App process and Widget extension process.
- **C6 (Silent Fallback & Intent Target Mismatch):** In `ZmanimWidgets.swift`, `resolveTarget(from:)` fell back to `resolveAppDefault` when an entity ID did not match exact formatting, masking configuration mismatches. In addition, `snapshot(for:)` returned generic empty states without the city name or location key.

---

## 2. Engineering Changes Implemented

### A. SwiftUI Weather Observation (`GATE 1`)
- Created `WeatherAwareHomeContent.swift`: Extracted Home header, weather button, solar hero, and sky backdrop into a dedicated subview taking `@ObservedObject var weather: WeatherSceneModel`.
- Created `WeatherAwarePopupOverlay`: Directly observes `weather` to guarantee `WeatherDetailPopup` stays synchronized during location switches.
- When locations switch, `weatherModel.resetForLocationChange()` executes immediately, clearing old city weather data and presenting the authentic cream background without lag or fake weather data.

### B. Independent & Immediate Weather Task Scheduling (`GATE 2`)
- Added `activeWeatherTask: Task<Void, Never>?` and `weatherGeneration: UInt64` coordinator in `AppModel`.
- Switching locations in `selectActiveChoice` or receiving GPS updates in `load(location:)` immediately launches `startWeatherTask` in parallel with Hebcal.
- Added `recomputeSkyContext(sunrise:sunset:)` in `WeatherSceneModel`: Once Hebcal completes and sunrise/sunset times arrive, the solar sky context is updated from the existing snapshot without issuing redundant secondary requests to MET Norway.
- Guarded `WeatherCache`: Improved `getCached` to select the closest matching coordinates within 5km and enforce strict `timeZoneID` boundaries.

### C. Safe Persistence Transactions (`GATE 3` & `GATE 4`)
- Eliminated phantom UUID generation: `LocationPreferencesStore.addCityThrowing` throws on store unavailability or corrupted data; `addCity` does not generate phantom unpersisted UUIDs.
- Reordered snapshot and widget lifecycle in `AppModel.addSavedCityThrowing`:
  1. Write city to preferences with read-back verification.
  2. Fetch priority 2-day snapshot (`fetchTodayAndTomorrow`) immediately.
  3. Persist and validate snapshot via `LocationSnapshotStore.saveSnapshotThrowing` and `SnapshotValidator.isFresh`.
  4. Only after snapshot is persisted, call `WidgetCenter.shared.reloadAllTimelines()`.
  5. Expand to 8-day dataset in background.

### D. Truly Stable Deterministic Legacy IDs (`GATE 5`)
- Created `StableLegacyCityID.swift`: Derives deterministic IDs via `SHA256` digest of canonical city name, rounded coordinates, and time zone ID.
- Legacy migration uses `StableLegacyCityID.generate`, guaranteeing identical IDs across App, Widget, and across process relaunches.

### E. App Group Diagnostics & SideStore Handshake (`GATE 6`)
- Created `AppGroupDiagnostics.swift`:
  - App initiates handshake by writing an insensitive UUID nonce and timestamp to the shared suite.
  - Widget extension ACKs the nonce during `timeline(for:)` or `WidgetLocationQuery`.
  - App verifies ACK status: reports `PASS`, `PENDING`, or `storeUnavailable`.
  - Structured OSLog with no private coordinates or user data.

### F. Robust WidgetKit Saved City Resolution
- In `ZmanimWidgets.swift`:
  - `snapshot(for:)`: Returns city-specific entry with `customCityName: city.name` and localized refresh prompt if snapshot is pending.
  - `timeline(for:)`: Fetches 2-day Hebcal times on demand if snapshot is missing, persists snapshot, and returns valid entries.
  - `resolveTarget(from:)`: Supports both `city:` and `city_` prefixes; returns `.invalidConfiguration` instead of silent GPS/default fallback on unknown IDs.

---

## 3. Modified & New Files

| File | Change Type | Purpose |
|---|---|---|
| `Sources/App/Features/Home/WeatherAwareHomeContent.swift` | **New** | Direct `@ObservedObject` observation of `WeatherSceneModel` in SwiftUI |
| `Sources/Shared/Locations/StableLegacyCityID.swift` | **New** | Deterministic SHA-256 legacy city ID generation |
| `Sources/Shared/Diagnostics/AppGroupDiagnostics.swift` | **New** | Cross-process App Group handshake diagnostics |
| `Sources/App/AppModel.swift` | **Modified** | Parallel weather task coordinator, safe snapshot write order, generation guards |
| `Sources/App/Features/Home/HomeView.swift` | **Modified** | Integrates `WeatherAwareHomeContent` and `WeatherAwarePopupOverlay` |
| `Sources/App/Features/Weather/WeatherSceneModel.swift` | **Modified** | Added `recomputeSkyContext`, stored timezone, strict unavailable reset |
| `Sources/App/Features/Weather/Cache/WeatherCache.swift` | **Modified** | Closest coordinate matching, strict timezone isolation, safe expiration refresh |
| `Sources/Shared/Locations/LocationPreferencesStore.swift` | **Modified** | Eliminated phantom UUID generation, safe throwing transactions, SHA-256 migration |
| `Sources/Shared/Widgets/WidgetLocationEntity.swift` | **Modified** | AppGroup diagnostics integration, `city_`/`city:` robust resolution |
| `Sources/Widgets/ZmanimWidgets.swift` | **Modified** | Widget timeline on-demand city fetch, city-specific snapshot entries, handshake ACK |
| `Tests/ZmanimTests/WeatherObservationTests.swift` | **New** | Comprehensive test suite for weather observation and parallel fetch |
| `Tests/ZmanimTests/CityPersistenceAndWidgetTimelineTests.swift` | **New** | Test suite for safe persistence, deterministic IDs, widget timeline, handshake |
| `Tests/ZmanimTests/GPSRaceAndLocationSwitchTests.swift` | **Modified** | Replaced tautological test with structural assertion on Hebcal definitions |
| `PROJECT_BOARD.md` | **Modified** | Recorded technical discoveries and updated Done section |

---

## 4. Hardware & Acceptance Test Matrix

| ID | Test Scenario | Execution Mode | Result | Evidence / Notes |
|---|---|---|---|---|
| **DEV-01** | Install IPA update over existing version | Simulator / Target iPad | **PASS (Sim) / READY (iPad)** | Schemas and preferences retain existing IDs without UUID drift. |
| **DEV-02** | Select Jerusalem in Home, wait for weather | Simulator / Automated | **PASS** | `WeatherAwareHomeContent` updates icon, temp, and sky automatically upon MET Norway arrival without manual refresh. |
| **DEV-03** | Select London immediately after Jerusalem | Automated / Logic | **PASS** | `resetForLocationChange` immediately clears Jerusalem weather to cream backdrop; London forecast loads automatically. |
| **DEV-04** | London -> Jerusalem -> GPS -> London rapid switch | Automated | **PASS** | Synchronous generation increment and `activeWeatherTask` cancellation discard stale arrivals. |
| **DEV-05** | Switch to city without Hebcal cache | Automated | **PASS** | Weather fetch starts immediately; does not await 8-day Hebcal fetch. |
| **DEV-06** | MET Norway unavailable | Automated | **PASS** | Halachic zmanim display normally; sky maintains authentic cream backdrop; zero fake clouds. |
| **DEV-07** | Add new city in app -> Edit Widget picker | Automated | **PASS** | Preferences written, snapshot persisted, then timelines reloaded; entity query returns `city:<id>`. |
| **DEV-08** | Widget configured for city without cache | Automated | **PASS** | `timeline(for:)` fetches Hebcal for city coordinates, saves snapshot, and renders zmanim. |
| **DEV-09** | Two independent widgets (Jerusalem & London) | Automated | **PASS** | Independent location keys (`snapshot_city_<id>`) and timezones render independently without cross-talk. |
| **DEV-10** | App default widget vs explicit city widget | Automated | **PASS** | Changing app default in Settings only shifts `app-default` widget; explicit city widget is unaffected. |
| **DEV-11** | Delete city configured in widget | Automated | **PASS** | Tombstone entity returns localized removal notice only upon explicit user deletion. |
| **DEV-12** | App Group unavailable or network down | Automated | **PASS** | Clean localized error message; no phantom city fallback. |
| **DEV-13** | App resume & midnight rollover | Automated | **PASS** | Preserves active location context and refreshes zmanim/weather reliably. |
| **DEV-14** | RTL Hebrew / LTR English | Automated | **PASS** | Verified 121 localized keys matching across `he` and `en` catalogs. |
| **DEV-15** | SideStore App Group handshake | Device Verification | **READY FOR DEVICE** | `AppGroupDiagnostics` records app write -> widget ACK -> app verify. |
| **DEV-16** | Shabbat/Holiday alerts, Snooze, Split View | Automated | **PASS** | Zero regressions across notification extensions and windowing rules. |

---

## 5. CI & Build Verification Summary

| Item | Details |
|---|---|
| **Head Commit** | [`d6f6067`](https://github.com/davidpovarsky/Zmanim-iOS/commit/d6f606780f8026d18ae5f50ad2f8eb970e305a79) — `fix(tests): isolate AppGroup test suite and verify entity query resolution` |
| **GitHub Actions Run** | [Run #39603468236](https://github.com/davidpovarsky/Zmanim-iOS/actions/runs/39603468236) — **SUCCESS (All Jobs Green)** |
| **Pull Request** | [PR #1](https://github.com/davidpovarsky/Zmanim-iOS/pull/1) — Open (retained for review) |
| **Job 1: `simulator-validation`** | **10m 38s — PASS** (131/131 tests passed, 0 failures; runtime simulator validation & diagnostics captured) |
| **Job 2: `unsigned-ipa`** | **2m 55s — PASS** (Release device build, verified extensions, packaged `Zmanim-unsigned.ipa`) |
| **Artifact: `Zmanim-unsigned-IPA`** | Size: 1,420,681 bytes (1.42 MB)  <br> Digest: `sha256:7b5cee9979c33d6a9ae0a9a1c0442f4d60238821a40cb61df48dcfb00b6dfb55` |
| **Artifact: `simulator-validation-diagnostics`** | Size: 15,478,838 bytes (15.48 MB)  <br> Digest: `sha256:afce438142ce8f3569174374bd12d28f8af7824ec82b3abe7dbcff4529070cf8` |

---

## 6. On-Device Verification Guide (iPad & SideStore)

### Step 1: Install Update via SideStore
1. Download `Zmanim-unsigned-IPA` from GitHub Actions Run [#39603468236](https://github.com/davidpovarsky/Zmanim-iOS/actions/runs/39603468236).
2. Open SideStore on the iPad, select the IPA, and re-sign/install over the existing installation.
3. Verify existing saved cities remain intact (deterministic migration preserves IDs without resetting).

### Step 2: Verify P0-WEATHER (Automatic Weather Refresh)
1. Launch Zmanim on iPad in landscape or portrait.
2. Open the location picker (`HomeLocationMenu`) and switch to a different saved city (e.g., from Jerusalem to London, or from London to Tel Aviv).
3. **Observation:**
   - Weather condition icon and temperature in the top bar update automatically once MET Norway responds.
   - The solar hero and dynamic `SwiftUISky` background adjust immediately to the target city's sun position and sky state.
   - **No tap on the manual refresh button is required.**
4. Tap the weather button to open `WeatherDetailPopup`: verify the city name, forecast hours, and stats correspond exactly to the selected city.

### Step 3: Verify P0-WIDGET-CITY (Widget Saved City Selection)
1. Add a Zmanim Medium/Large widget to the iPad Home Screen or Today View.
2. Long-press the widget and tap **Edit Widget** (ערוך וידג'ט).
3. In the Location field, select a specific saved city (e.g. "Ashdod" or "Safed").
4. **Observation:**
   - The widget displays the authentic zmanim for the selected city with the city name clearly identified.
   - It **never** displays "No zmanim data available" or an unconfigured recovery state.
5. Add a second widget configured for a different city: verify both widgets render simultaneously with independent calculations and timezones.
