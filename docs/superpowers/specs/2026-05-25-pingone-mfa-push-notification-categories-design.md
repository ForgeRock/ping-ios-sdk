# Design: PingOneMFA Push Notification Categories & Action Handling

**Date:** 2026-05-25  
**Status:** Proposed

---

## Problem

`PingOneMFA` already wraps the background push delivery path (`collectPush` → `PingOne.processRemoteNotification`). Two pieces are missing for full actionable push notification support:

1. **Category registration** — apps must pass `UNNotificationCategory` objects to `UNUserNotificationCenter` at startup so the system shows approve/deny buttons on the banner. `PingOneSDK` owns these categories; `PingOneMFA` doesn't expose them.
2. **Banner action handling** — when a user taps an action button directly on the notification banner, the app delegate receives `UNNotificationResponse` and must call `PingOne.processRemoteNotificationAction`, not `processRemoteNotification`. This is a different SDK entry point that carries the `actionIdentifier` and `authenticationMethod`, allowing the SDK to handle the action internally without the app having to call `.approve()`/`.deny()` itself.

---

## Design

### Two additions to `PingOneMFA.swift`

No new files. Both methods follow the same `nonisolated static` pattern used throughout the file.

---

### 1. `getNotificationCategories() -> Set<UNNotificationCategory>`

```swift
public nonisolated static func getNotificationCategories() -> Set<UNNotificationCategory> {
    return PingOne.getUNNotificationCategories()
}
```

- Synchronous — `PingOneSDK` returns the set immediately, no async work.
- Requires adding `import UserNotifications` to `PingOneMFA.swift`.
- The caller is responsible for passing the result to `UNUserNotificationCenter.current().setNotificationCategories(...)`. `PingOneMFA` does not call it internally — this keeps the module free of UIKit/UNUserNotificationCenter side effects and composable with the app's own categories.

**Caller usage (AppDelegate / SceneDelegate):**
```swift
UNUserNotificationCenter.current().setNotificationCategories(
    PingOneMFA.getNotificationCategories()
)
```

---

### 2. `processNotificationAction(identifier:authenticationMethod:userInfo:) async throws -> PushNotification?`

```swift
public nonisolated static func processNotificationAction(
    identifier: String,
    authenticationMethod: String?,
    userInfo: [AnyHashable: Any]
) async throws -> PushNotification?
```

- Wraps `PingOne.processRemoteNotificationAction(_:authenticationMethod:forRemoteNotification:completionHandler:)`.
- Returns `PushNotification?`:
  - `nil` — SDK handled the action internally (e.g. the banner button was tapped and the SDK approved/denied without needing app UI). No further action needed.
  - non-nil — SDK requires the app to present approve/deny UI. Caller calls `.approve()` or `.deny()` on the returned value.
- Reuses the existing `PushNotification` type — no new model.
- APNS `title`/`message` are parsed from `userInfo` using the same logic as `collectPush`.

**Caller usage (UNUserNotificationCenterDelegate):**
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    Task {
        do {
            let notification = try await PingOneMFA.processNotificationAction(
                identifier: response.actionIdentifier,
                authenticationMethod: "user",
                userInfo: response.notification.request.content.userInfo
            )
            if let notification {
                // Present approve/deny UI using notification
            }
        } catch {
            // Handle error
        }
        completionHandler()
    }
}
```

---

## Error Handling

Both methods follow the existing `PingOneMFAError` pattern — errors from the SDK are wrapped and re-thrown as `PingOneMFAError`.

---

## Files Changed

| File | Change |
|------|--------|
| `PingOneMFA/PingOneMFA/PingOneMFA.swift` | Add `import UserNotifications`; add `getNotificationCategories()` and `processNotificationAction(identifier:authenticationMethod:userInfo:)` |

No new files. No changes to `PushNotification.swift`, `PingOneMFAConfig.swift`, or tests (unit tests for SDK wrappers are limited by the fact that `PingOneSDK` is a binary framework).

---

## Out of Scope

- `PingOne.pushNotification(allowed:)` — allow/disable push. Not included; straightforward to add later if needed.
- `PingOne.testRemoteNotification(_:)` — test helper. Internal use only.
- Registering `UNUserNotificationCenter` categories automatically inside `PingOneMFA.initialize()` — kept out to avoid UIKit side effects in the SDK layer.
