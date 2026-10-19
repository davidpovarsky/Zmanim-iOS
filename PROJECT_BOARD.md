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

- **MET Norway Symbol Mapping Precedence**: Symbol codes containing `snowshowers` (e.g. `snowshowers_day`) also match substring `showers`. If `showers` or `rain` is matched first, snow showers are misclassified as rain. Strictly prioritizing snow/sleet condition checks before generic showers/rain ensures accurate precipitation rendering in both the forecast card and `SwiftUISky`.
- **WidgetKit Interactive Paging Expiration & Timeline Entries**: When paging widgets with `AppIntent` without opening the host app, WidgetKit reloads timelines asynchronously. Pairing `expiresAt = now + 60s` in the App Group with a future timeline entry at `expiresAt` (page 0) allows best-effort automatic return to the initial page while respecting WidgetKit energy budgets.
- **End-of-Day Next Zman Resolver**: Filtering only `todayItems.first(where: { $0.date > now })` causes false "loading" states after the last daily zman. Sourcing upcoming events from multi-day Hebcal data and tagging events on subsequent local days with a "מחר" indicator provides continuous, truthful display without unneeded network requests.

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

- [x] Master Implementation: MET Norway, No-Fake Weather, Widget 5-Item Paging, End-of-Day Next Zman, and SwiftUISky TimeZone Support
  - Implemented: 2026-10-19
  - Branch: `feature/met-weather-widget-paging-eod`
  - Notes: Full end-to-end execution of prompt specifications A–I. Replaced Open-Meteo with MET Norway compact client; removed `fallbackReport`; implemented `WeatherDetailPopup` and `WeatherHeaderButton` in the exact top-left marked location; partitioned widget day items into stable 5-item pages with `chevron.down`/`chevron.up` App Intents and 60s best-effort reversion; resolved end-of-day next zman with "מחר" tag; passed city time zone to `SkyBackdrop`; added comprehensive unit test suites for all pure logic domain models.

## Archive

Older completed/superseded items that still have historical value.
