# Zmanim-iOS — Weather Refresh & Widget City Selection Investigation

**Date:** 2026-10-21  
**Baseline Commit:** `8a096085e69113dd558f914c0b22a51fb8d25f57`  
**Branch:** `feature/met-weather-widget-paging-eod`  
**Target Environment:** iPadOS 27, Xcode 26.6 / iOS 26 SDK (iOS 17.0+ compatibility)

---

## 1. Investigation Matrix

| ID | Symptom | Source Path & Function | Hypothesis | Reproduction | Observed Evidence | Fix | Test | Provenance |
|---|---|---|---|---|---|---|---|---|
| **OBS-01** | Weather & SwiftUISky background do not refresh automatically when switching city in `HomeLocationMenu`; only manual refresh updates them. | `Sources/App/AppModel.swift`: line 19 (`@Published var weatherModel = WeatherSceneModel()`), `Sources/App/Features/Home/HomeView.swift`: lines 6-126 | `AppModel` wraps `WeatherSceneModel` (an `ObservableObject`) as `@Published`. In SwiftUI, updates to nested `ObservableObject` properties (`weatherDisplay`, `condition`, `cloudCover`) do not fire the parent `AppModel.objectWillChange`. `HomeView` observes only `AppModel` and lacks direct observation of `weatherModel`. | Launch app with City A. Switch to City B. MET Norway fetch completes, but `HomeView` does not re-render until 30s `TimelineView` tick or manual refresh button press. | Code analysis: `HomeView` has `@EnvironmentObject private var model: AppModel`. `WeatherSceneModel` properties mutate on background completion, firing `weatherModel.objectWillChange`. Parent `model.objectWillChange` is never emitted. | Separate weather presentation into `WeatherAwareHomeContent` with direct `@ObservedObject var weather: WeatherSceneModel`, or forward `weatherModel.objectWillChange` to `AppModel`. | `testWeatherObservationPublishesHeaderAndSkyOnForecastCompletion` | **Proven in Code** |
| **ORD-02** | Weather fetch is blocked by 8-day Hebcal network call on city switch. | `Sources/App/AppModel.swift`: `selectActiveChoice(.savedCity)`, `loadSavedCity` | `selectActiveChoice` delegates to `loadSavedCity`, which awaits `HebcalService.fetchDays(..., count: 8)` before invoking `refreshWeather()`. If Hebcal is slow or fails, weather is delayed or never fetched. | Switch to saved city with no cached snapshot. Notice weather does not begin loading until 8 Hebcal days finish downloading. | Code analysis: Lines 288-316 in `AppModel.swift`: `HebcalService.fetchDays(..., count: 8)` is awaited first; `refreshWeather` is at line 316. | Decouple weather fetch: start an independent `Task` for MET Norway immediately in `selectActiveChoice` and `load(location:)`. Recompute sky context once Hebcal arrives. | `testSwitchToSavedCityStartsWeatherBeforeHebcalCompletes` | **Proven in Code** |
| **ORD-03** | Race conditions between slow City A and fast City B weather requests. | `Sources/App/AppModel.swift`: `refreshWeather`, `Sources/App/Features/Weather/WeatherSceneModel.swift`: `update` | Lack of a dedicated cancellable `activeWeatherTask` in `AppModel`. Rapid switching can cause out-of-order weather arrivals if not guarded by target identity and generation. | Rapid switch: City A (delayed) -> City B (fast). City A responds after City B and overwrites weather. | Code analysis: `AppModel` has `loadGeneration` for Hebcal, but `refreshWeather` did not cancel prior tasks or verify active identity before committing. | Add `activeWeatherTask: Task<Void, Never>?`, increment generation synchronously before await, cancel prior task, and verify identity upon commit. | `testSwitchingLocationCancelsOrIgnoresOldWeatherResponse` | **Proven in Code** |
| **SAV-04** | Saving new city can return phantom `SavedCity` with unpersisted UUID on failure. | `Sources/Shared/Locations/LocationPreferencesStore.swift`: `addCity` (lines 136-147) | `addCity` swallows errors with `try?` and returns `fallbackCity = SavedCity(id: UUID().uuidString...)`. The app thinks the city is saved, but Widget extension cannot resolve the ID. | Force failing store (e.g. invalid suite or mock). Call `addCity`. Observe a `SavedCity` with random UUID returned while store is unchanged. | Lines 142-146 in `LocationPreferencesStore.swift`: `let fallbackCity = SavedCity(id: UUID().uuidString...); return (loadPreferences(), fallbackCity)`. | Eliminate `fallbackCity` in production. Use `addCityThrowing` throughout `AppModel` and report errors. | `testAddCitySaveFailureDoesNotReturnPhantomCity` | **Proven in Code** |
| **WID-05** | Widget shows "No zmanim data available" / "Open app to refresh" when user selects a saved city in Edit Widget. | `Sources/App/AppModel.swift`: `addSavedCity` (lines 221-250), `Sources/Widgets/ZmanimWidgets.swift`: `snapshot(for:)`, `timeline(for:)` | 1) `AppModel.addSavedCity` calls `WidgetCenter.shared.reloadAllTimelines()` BEFORE fetching and persisting `ZmanSnapshot`. After background fetch succeeds, it does not call reload again. 2) Widget `snapshot(for:)` does not return city-specific placeholder or existing snapshot. 3) Widget `timeline(for:)` performs 3 network calls; if timed out, it falls into recovery state. | Add city in app. Immediately configure widget with this city. Widget receives reload event before snapshot is written, finds nil snapshot, and displays empty recovery. | In `addSavedCity`: line 229 calls `reloadAllTimelines()`, lines 235-247 asynchronously fetch and save snapshot without subsequent reload. In `ZmanimWidgets.swift`: `snapshot(for:)` returns `state: widget.open_app_to_refresh` if no fresh snapshot. | Reorder: write preferences -> fetch priority 2-day Hebcal -> validate & save snapshot -> THEN call `reloadAllTimelines()`. In widget timeline: robustly fetch Hebcal with timeout guard and fall back gracefully. | `testSaveCitySnapshotBeforeWidgetReload`, `testConfiguredCityWithoutCacheTriggersTimelineFetch` | **Proven in Code** |
| **MIG-06** | Legacy migration uses `String.hashValue`, causing unstable entity IDs across processes and app launches. | `Sources/Shared/Locations/LocationPreferencesStore.swift`: line 204 | `Swift.String.hashValue` uses SipHash with randomized per-process seed. Migration executed in app vs widget produces divergent IDs, causing widget intent configuration to break. | Compare `stableHash` computed in App process vs Widget extension process for identical string. The IDs differ across process boundaries. | Line 204: `let stableHash = abs("\(cleanName)_\(resolved.latitude)_\(resolved.longitude)".hashValue)`. Swift documentation explicitly notes `hashValue` is not execution-stable. | Replace with deterministic SHA-256 hash formatted stably (e.g. `legacy_<hex>`). Preserve existing already-persisted IDs. | `testDeterministicLegacyIDsAcrossProcessReinitialization` | **Proven in Code** |
| **GRP-07** | App Group sharing may be blocked or dropped post-signing by SideStore. | `Supporting/Zmanim.entitlements`, `Supporting/ZmanimWidgets.entitlements`, SideStore app signing | Free Apple developer accounts or SideStore re-signing may fail to preserve `com.apple.security.application-groups` across main app and widget appex. | Install unsigned IPA via SideStore on iPad without active App Group provisioning entitlement. Observe widget unable to access shared suite. | Issue report: SideStore issue #1437. Unsigned IPA verification only checks pre-signing plist, not post-SideStore signature. | Add cross-process handshake diagnostics (`AppGroupDiagnostics`): App writes nonce, Widget ACKs nonce with timestamp; distinct UI error if store unavailable. | `testAppGroupHandshakeDiagnostics` | **Requires Verification after SideStore signing** |

---

## 2. Hypothesis Validation & Reproduction Plan

### A. Weather Observation Bug
1. In `HomeView.swift`, create an isolated test harness or preview that modifies `weatherModel.weatherDisplay` directly.
2. Verify that without `@ObservedObject` on `weatherModel` or Combine forwarding on `AppModel`, `HomeView` does not invalidate its rendering tree.
3. Fix: Provide `WeatherAwareHomeContent` with direct `@ObservedObject var weather: WeatherSceneModel`.

### B. Widget City Data Bug
1. Create a unit test where `AppModel.addSavedCity` order of operations is monitored: preferences write -> snapshot write -> WidgetCenter reload.
2. Verify that if WidgetCenter reloads before snapshot write, `LocationSnapshotStore.loadSnapshot` returns `nil`.
3. In `ConfigurableZmanProvider`, verify behavior when `city:<id>` is requested: ensure `HebcalService` is called with city coordinates and time zone, and snapshot is saved under `snapshot_city_<id>`.

---

## 3. Logging & Privacy Specification

All logging will utilize Apple's unified logging system (`os.Logger`):
- Subsystem: `com.davidpovarsky.Zmanim`
- Categories:
  - `App.WeatherCoordinator`
  - `App.CityPersistence`
  - `Widgets.ConfigurableProvider`
  - `Shared.AppGroupDiagnostics`
- Privacy: All coordinates and locality names remain private (`privacy: .private` or omitted). Status codes, generation counters, and handshake nonces use `privacy: .public`.
