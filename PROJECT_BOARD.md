# Project Board

This is a living working-memory document for this repository.
It is intentionally lightweight. Humans and coding agents should update it when useful discoveries, ideas, plans, optimizations, problems, or follow-up work arise during normal development.
Do not turn this into a duplicate issue tracker or a dump of temporary thoughts.

## Inbox

Quick captures that still need classification.

## Ideas & Opportunities

Potential improvements, features, optimizations, or architectural ideas.

## Discoveries & Tips

Useful technical discoveries, undocumented behavior, shortcuts, implementation tricks, platform behavior, or reusable knowledge discovered while working.

- **Notification Content Extension Storyboard Class Resolution**: When `MainInterface.storyboard` specifies `customClass="NotificationViewController" customModule="ZmanimNotificationContent"`, annotating the Swift class with `@objc(NotificationViewController)` forces the runtime name to be un-namespaced. `UIStoryboard` attempts `NSClassFromString("ZmanimNotificationContent.NotificationViewController")`, returns `nil`, and silently instantiates a blank `UIViewController`. Removing `@objc(...)` lets Swift register the fully-qualified symbol so UIStoryboard resolves the custom view controller.
- **Snooze Scheduling Ownership & Prefix Isolation**: Having both the notification content extension and the host app schedule snoozes independently creates duplicate notification IDs and race conditions. Forwarding action responses via `completion(.dismissAndForwardAction)` to `NotificationCoordinator` establishes a single owner. In addition, partitioning pending requests by prefix (`zmanim.daily.*`, `zmanim.test.*`, `zmanim.snooze.*`) ensures daily zmanim refreshes do not purge active snoozes.
- **Unified Solar Arc Geometry**: Combining quadratic Bézier curves with de Casteljau subdivision ensures the completed arc endpoint and sun marker center match with zero coordinate divergence across all widget sizes and the main app view.
- **Notification Content Extension Framework Linking**: When defining a `UNNotificationContentExtension` target via XcodeGen, `UserNotificationsUI.framework` must be explicitly declared under `dependencies: [sdk: UserNotificationsUI.framework]` and `-framework UserNotificationsUI` linker flags. Without this, the linker omits the extension point symbols; `ExtensionFoundation` then aborts at runtime with `Unable to find NSExtensionContextClass (_UNNotificationContentExtensionVendorContext) in extension bundle - did you link the framework that declares the extension point?` with SIGTRAP, causing SpringBoard to fall back to an empty blank white view.
- **XCUIApplication State During SpringBoard Dismissals**: When SpringBoard displays an expanded notification overlay or handles an action button, the host app process transitions through suspended states while SpringBoard animates dismissal. Immediate synchronous checks on `app.state == .runningForeground` fail transiently during animation; `app.wait(for: .runningForeground, timeout:)` or asserting `app.state != .notRunning` accurately confirms host process survival and foreground resumption.

- **AppIntentConfiguration Dynamic Widget Entity Query & Tombstone Isolation**: In WidgetKit `AppIntentConfiguration` (`WidgetConfigurationIntent`), returning tombstone entities (`location.city_removed_widget`) when a saved city has been deleted prevents silent fallback to unintended locations or runtime crashes in the widget extension. In addition, providing explicit `app-default` and `current-gps` synthetic entities allows users to cleanly toggle between dynamic app-following, direct GPS, and pinned cities.
- **Upcoming Zmanim Pager with Multi-Day Overflow**: Slicing widget 5-item pages strictly from `referenceDate` (`date >= now`) rather than the start of the day prevents widgets from displaying morning zmanim that have already passed when viewed in the afternoon. Continuing into tomorrow's zmanim when fewer than 5 items remain today ensures full 5-card pages at all hours without false empty or loading states.
- **Per-Location State Partitioning in Widget Paging Intents**: Parameterizing `NextWidgetPageIntent` and `PreviousWidgetPageIntent` with a stable `locationKey` ensures that multiple widgets configured with different locations on the same home screen do not corrupt or step on each other's paging indexes or 60-second reversion timers.
- **MET Norway Symbol Mapping Precedence**: Symbol codes containing `snowshowers` (e.g. `snowshowers_day`) also match substring `showers`. If `showers` or `rain` is matched first, snow showers are misclassified as rain. Strictly prioritizing snow/sleet condition checks before generic showers/rain ensures accurate precipitation rendering in both the forecast card and `SwiftUISky`.
- **OneBusAway Israel Weather Package Extraction**: Porting the authoritative OneBusAway Israel weather UI and formatting components (`WeatherDetailPopup`, `WeatherDisplay`, `WeatherFormatter`) into a focused local Swift package (`Packages/OneBusAwayWeather`) preserves exact visual geometry, icon palettes, 3-slot stats with literal em-dash placeholders, and template `"j"` short-hour formatting while isolating the app from transitive transit/map dependencies.
- **WidgetKit Interactive Paging Expiration & Timeline Entries**: When paging widgets with `AppIntent` without opening the host app, WidgetKit reloads timelines asynchronously. Pairing `expiresAt = now + 60s` in the App Group with a future timeline entry at `expiresAt` (page 0) allows best-effort automatic return to the initial page while respecting WidgetKit energy budgets.
- **End-of-Day Next Zman Resolver**: Filtering only `todayItems.first(where: { $0.date > now })` causes false "loading" states after the last daily zman. Sourcing upcoming events from multi-day Hebcal data and tagging events on subsequent local days with a "מחר" indicator provides continuous, truthful display without unneeded network requests.
- **Liquid Glass API Adoption & Availability Isolation**: Under iOS 26+ (`#available(iOS 26.0, *)`), system Liquid Glass is activated via `.glassEffect(.regular/.clear, in: shape)`. Wrapping it behind `GlassSurfaceModifier` ensures compilation on earlier SDKs while providing modern Apple design without obscuring dynamic `SwiftUISky` luminance.
- **Pure SolarPhase Model & Nighttime Horizon Rendering**: Decoupling the continuous daylight progression into a distinct `SolarPhase` enum (`beforeSunrise`, `daylight`, `afterSunset`, `unavailable`) prevents false rendering of active golden arcs and sun markers across both the host app and widgets during night hours.
- **RTL Symmetrical Parabola for Halachic Solar Arc**: Inverting the horizon endpoints in `SolarArcGeometry` when `isRTL` is true places sunrise in the east (right) and sunset in the west (left) in Hebrew locale, while de Casteljau curve subdivision guarantees exact coincidence between the golden progress arc tip and the sun marker center.
- **Location Preferences Store Resilience & Deterministic Migration**: Distinguishing store unavailability from explicit deletions via explicit `removedCityIDs` tombstones and using deterministic hashes (`legacy_<hash>`) for legacy migrations prevents WidgetKit intents from misdiagnosing saved cities as deleted.
- **Dynamic Localization & Elimination of Hardcoded UI Status in Core Entities**: Storing dynamic status strings like "Current Location" or "המיקום הנוכחי" in persistence snapshots causes language mismatches when system language switches. Resolving labels at render time and storing only verified geocoded localities or empty strings eliminates cross-locale corruption.
- **Multi-Location Cache Isolation & Front-Loaded Hebcal Queries**: Partitioning `WeatherCache` entries by coordinate keys and splitting Hebcal requests into an immediate 2-day priority fetch and deferred 6-day background fetch guarantees instant, synchronized UI transitions without cross-city cache invalidation races.
- **WidgetKit StaticConfiguration Instance Isolation Boundary**: In WidgetKit `StaticConfiguration`, timeline providers and `AppIntent` handlers do not receive a persistent per-instance widget ID. Attempting to simulate per-widget state without an `AppIntentConfiguration` parameter creates desynchronization. Shared state with 60-second expiration remains the standard best-effort model.
- **Atomic City Search & Time Zone Resolution**: Sourcing suggestions through `MKLocalSearchCompleter` and resolving coordinates and time zones atomically via `MKLocalSearch` prevents corrupted halachic times and out-of-order race conditions when switching between GPS and fixed locations.

## Experiments / Investigations

Things worth testing or researching before deciding whether to implement them.

## Open Questions

Important unresolved questions or uncertainties.

## Planned / Todo

Concrete work that is worth doing but is not part of the current task.

Use Markdown checkboxes where useful:

- [ ] Example item

## Done

Completed items that are still useful to retain because they document an important decision, discovery, or implementation.

- [x] Widget Now-Based Paging, Location Localization, Multiple Saved Cities, and Independent Widget Configuration
  - Implemented: 2026-10-20
  - Branch: `feature/met-weather-widget-paging-eod`
  - Notes: Migrated to `AppIntentConfiguration` (`WidgetLocationConfigurationIntent`) allowing each widget to independently track App Default, Current GPS, or any saved city; replaced beginning-of-day slicing with `UpcomingZmanPager` starting from reference moment with cyclic navigation and tomorrow overflow; decoupled HomeHeader into independent `HomeLocationMenu` and `WeatherHeaderButton` with full English/Hebrew localizations; decoupled notification scheduling to strictly follow persistent default location; added comprehensive test suites across paging, multi-city persistence, and entity queries.
- [x] Authoritative OneBusAway Israel Weather Component Port
  - Implemented: 2026-10-19
  - Branch: `feature/met-weather-widget-paging-eod`
  - Notes: Ported original `WeatherDetailPopup`, `WeatherDisplay`, `WeatherFormatter` from `onebusaway-ios@6b8d381` into local package `Packages/OneBusAwayWeather`. Retired custom duplicate implementations. Connected to genuine MET Norway client via `ZmanimWeatherDisplayAdapter`. Added complete Hebrew translations and time zone-aware hour formatting.
- [x] Master Implementation: MET Norway, No-Fake Weather, Widget 5-Item Paging, End-of-Day Next Zman, and SwiftUISky TimeZone Support
  - Implemented: 2026-10-19
  - Branch: `feature/met-weather-widget-paging-eod`
  - Notes: Full end-to-end execution of prompt specifications A–I. Replaced Open-Meteo with MET Norway compact client; removed `fallbackReport`; implemented `WeatherDetailPopup` and `WeatherHeaderButton` in the exact top-left marked location; partitioned widget day items into stable 5-item pages with `chevron.down`/`chevron.up` App Intents and 60s best-effort reversion; resolved end-of-day next zman with "מחר" tag; passed city time zone to `SkyBackdrop`; added comprehensive unit test suites for all pure logic domain models.
- [x] iPadOS 26/27 Modernization: Adaptive Windowing, Liquid Glass, Sun Geometry, Atomic Location & Notifications
  - Implemented: 2026-10-20
  - Branch: `feature/met-weather-widget-paging-eod`
  - Notes: Updated CI pipeline to macOS 26 / Xcode 26.6 with strict iOS SDK >= 26 check and windowing verification script (`verify-ipa-windowing.sh`); implemented `AdaptiveLayout`, `AdaptiveContainer`, and responsive subviews (`HomeHeader`, `NextZmanCard`, `WeatherDetailPopup`); added Liquid Glass support (`GlassSurface.swift`) and decoupled color tokens for system light/dark mode; pure `SolarPhase` model eliminating false nighttime sun dots and golden arcs across app and widgets; unified RTL/LTR parabola geometry (sunrise on right for Hebrew); integrated `CitySearchService` with `MKLocalSearchCompleter` and atomic location switching in `AppModel`; disentangled Shabbat and Holiday notifications with verified event planner `SpecialDayNotificationPlanner`; fixed `METNorwayWeatherClient` session injection; added 8 focused test suites.

## Archive

Older completed/superseded items that still have historical value.
