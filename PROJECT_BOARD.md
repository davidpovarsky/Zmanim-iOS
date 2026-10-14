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
- **XCUIApplication State During SpringBoard Dismissals**: When SpringBoard displays an expanded notification overlay or handles an action button, the host app process transitions through suspended states while SpringBoard animates dismissal. Immediate synchronous checks on `app.state == .runningForeground` fail transiently during animation; `app.wait(for: .runningForeground, timeout:)` or asserting `app.state != .notRunning` accurately confirms host process survival and foreground resumption.

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

Example:

- [x] Example improvement
  - Implemented: YYYY-MM-DD
  - Commit/PR: ...
  - Notes: ...

## Archive

Older completed/superseded items that still have historical value.
