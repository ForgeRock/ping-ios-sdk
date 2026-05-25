# PingOneMFA Push Notification Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `getNotificationCategories()` and `processNotificationAction()` to `PingOneMFA.swift`, following the existing `nonisolated static` async-wrapper pattern.

**Architecture:** Two methods are added to the existing `PingOneMFA` class. `getNotificationCategories()` is a synchronous pass-through to `PingOne.getUNNotificationCategories()`. `processNotificationAction()` mirrors `collectPush` but calls `PingOne.processRemoteNotificationAction` with the banner action identifier. A private `parseAPNSAlert` helper is extracted from `collectPush` to avoid duplicating the APNS payload parsing logic. Tests use the existing `MockPingOneMFA` pattern.

**Tech Stack:** Swift, XCTest, UserNotifications framework, PingOneSDK (binary framework)

---

### Task 1: Add `getNotificationCategories()` to `PingOneMFA`

**Files:**
- Modify: `PingOneMFA/PingOneMFA/PingOneMFA.swift`
- Modify: `PingOneMFA/PingOneMFATests/MockPingOneMFA.swift`
- Modify: `PingOneMFA/PingOneMFATests/PingOneMFATests.swift`

- [ ] **Step 1: Add tracking state for `getNotificationCategories` to `MockPingOneMFA.swift`**

Open `PingOneMFA/PingOneMFATests/MockPingOneMFA.swift`. Add `import UserNotifications` at the top alongside the existing `import Foundation`. Then add tracking vars after `collectPushReturnValue`:

```swift
import UserNotifications
```

After `nonisolated(unsafe) static var collectPushReturnValue: PushNotification? = nil`, add:

```swift
    nonisolated(unsafe) static var getNotificationCategoriesCalled = false
    nonisolated(unsafe) static var notificationCategoriesReturnValue: Set<UNNotificationCategory> = []
```

In the `reset()` method, add after `collectPushReturnValue = nil`:

```swift
        getNotificationCategoriesCalled = false
        notificationCategoriesReturnValue = []
```

After the `collectMobilePayload` method, add:

```swift
    static func getNotificationCategories() -> Set<UNNotificationCategory> {
        getNotificationCategoriesCalled = true
        return notificationCategoriesReturnValue
    }
```

- [ ] **Step 2: Write the failing test in `PingOneMFATests.swift`**

Add `import UserNotifications` at the top of `PingOneMFA/PingOneMFATests/PingOneMFATests.swift` alongside `import XCTest`. Then append this test at the end of `PingOneMFATests`, before the closing `}`:

```swift
    // MARK: - getNotificationCategories Tests

    func test21_MockGetNotificationCategoriesReturnsConfiguredCategories() {
        // Given
        let category = UNNotificationCategory(
            identifier: "test-pingone-category",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        MockPingOneMFA.notificationCategoriesReturnValue = [category]

        // When
        let categories = MockPingOneMFA.getNotificationCategories()

        // Then
        XCTAssertTrue(MockPingOneMFA.getNotificationCategoriesCalled)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.identifier, "test-pingone-category")
    }
```

- [ ] **Step 3: Run the test to confirm it compiles and passes**

```bash
cd /Users/giorakrasilshchik/Documents/Projects/iOS/forgerock-ping-ios-sdk/PingOneMFA && \
xcodebuild test \
  -project PingOneMFA.xcodeproj \
  -scheme PingOneMFATests \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  -only-testing:PingOneMFATests/PingOneMFATests/test21_MockGetNotificationCategoriesReturnsConfiguredCategories \
  2>&1 | grep -E "(PASS|FAIL|error:|Build succeeded|Build FAILED)"
```

Expected: `Test Suite 'PingOneMFATests' passed` (mock method exists, test exercises it directly — no real implementation needed).

- [ ] **Step 4: Add `getNotificationCategories()` to `PingOneMFA.swift`**

Open `PingOneMFA/PingOneMFA/PingOneMFA.swift`. Add `import UserNotifications` after the existing `import Foundation` line:

```swift
import Foundation
import UserNotifications
```

After the `collectMobilePayload` method (line ~225) and before the `reset()` method, add:

```swift
    /// Returns the set of `UNNotificationCategory` objects that PingOne requires for
    /// actionable push notifications. Pass the result to
    /// `UNUserNotificationCenter.current().setNotificationCategories(_:)` during app startup.
    ///
    /// - Note: Setting notification categories more than once overwrites prior values.
    ///   Merge with any app-defined categories before registering.
    public nonisolated static func getNotificationCategories() -> Set<UNNotificationCategory> {
        return PingOne.getUNNotificationCategories()
    }
```

- [ ] **Step 5: Run all tests to confirm nothing regressed**

```bash
cd /Users/giorakrasilshchik/Documents/Projects/iOS/forgerock-ping-ios-sdk/PingOneMFA && \
xcodebuild test \
  -project PingOneMFA.xcodeproj \
  -scheme PingOneMFATests \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  2>&1 | grep -E "(PASS|FAIL|error:|Build succeeded|Build FAILED|Test Suite)"
```

Expected: all 21 tests pass, build succeeds.

- [ ] **Step 6: Commit**

```bash
git add PingOneMFA/PingOneMFA/PingOneMFA.swift \
        PingOneMFA/PingOneMFATests/MockPingOneMFA.swift \
        PingOneMFA/PingOneMFATests/PingOneMFATests.swift
git commit -m "feat(PingOneMFA): add getNotificationCategories() wrapper"
```

---

### Task 2: Add `processNotificationAction()` to `PingOneMFA`

**Files:**
- Modify: `PingOneMFA/PingOneMFA/PingOneMFA.swift`
- Modify: `PingOneMFA/PingOneMFATests/MockPingOneMFA.swift`
- Modify: `PingOneMFA/PingOneMFATests/PingOneMFATests.swift`

- [ ] **Step 1: Add tracking state for `processNotificationAction` to `MockPingOneMFA.swift`**

After the `notificationCategoriesReturnValue` line, add:

```swift
    nonisolated(unsafe) static var processNotificationActionCalled = false
    nonisolated(unsafe) static var processNotificationActionReturnValue: PushNotification? = nil
    nonisolated(unsafe) static var lastActionIdentifier: String? = nil
    nonisolated(unsafe) static var lastActionAuthenticationMethod: String? = nil
```

In `reset()`, add after `notificationCategoriesReturnValue = []`:

```swift
        processNotificationActionCalled = false
        processNotificationActionReturnValue = nil
        lastActionIdentifier = nil
        lastActionAuthenticationMethod = nil
```

After the `getNotificationCategories()` method, add:

```swift
    static func processNotificationAction(
        identifier: String,
        authenticationMethod: String?,
        userInfo: [AnyHashable: Any]
    ) async throws -> PushNotification? {
        processNotificationActionCalled = true
        lastActionIdentifier = identifier
        lastActionAuthenticationMethod = authenticationMethod
        if shouldThrowError {
            throw PingOneMFAError(errorMessage)
        }
        return processNotificationActionReturnValue
    }
```

- [ ] **Step 2: Write the failing tests in `PingOneMFATests.swift`**

Append these tests after `test21_MockGetNotificationCategoriesReturnsConfiguredCategories`:

```swift
    // MARK: - processNotificationAction Tests

    func test22_MockProcessNotificationActionReturnsNilWhenSDKHandlesInternally() async throws {
        // Given — SDK handled action internally, no app UI needed
        MockPingOneMFA.shouldThrowError = false
        MockPingOneMFA.processNotificationActionReturnValue = nil

        // When
        let result = try await MockPingOneMFA.processNotificationAction(
            identifier: "com.pingidentity.approve",
            authenticationMethod: "user",
            userInfo: [:]
        )

        // Then
        XCTAssertTrue(MockPingOneMFA.processNotificationActionCalled)
        XCTAssertNil(result)
        XCTAssertEqual(MockPingOneMFA.lastActionIdentifier, "com.pingidentity.approve")
        XCTAssertEqual(MockPingOneMFA.lastActionAuthenticationMethod, "user")
    }

    func test23_MockProcessNotificationActionErrorPath() async {
        // Given
        MockPingOneMFA.shouldThrowError = true
        MockPingOneMFA.errorMessage = "Process notification action failed"

        // When / Then
        do {
            _ = try await MockPingOneMFA.processNotificationAction(
                identifier: "com.pingidentity.approve",
                authenticationMethod: "user",
                userInfo: [:]
            )
            XCTFail("Should have thrown an error")
        } catch let error as PingOneMFAError {
            XCTAssertEqual(error.message, "Process notification action failed")
            XCTAssertTrue(MockPingOneMFA.processNotificationActionCalled)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
```

- [ ] **Step 3: Run the new tests to confirm they compile and pass**

```bash
cd /Users/giorakrasilshchik/Documents/Projects/iOS/forgerock-ping-ios-sdk/PingOneMFA && \
xcodebuild test \
  -project PingOneMFA.xcodeproj \
  -scheme PingOneMFATests \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  -only-testing:PingOneMFATests/PingOneMFATests/test22_MockProcessNotificationActionReturnsNilWhenSDKHandlesInternally \
  -only-testing:PingOneMFATests/PingOneMFATests/test23_MockProcessNotificationActionErrorPath \
  2>&1 | grep -E "(PASS|FAIL|error:|Build succeeded|Build FAILED)"
```

Expected: both tests pass (mock method exists).

- [ ] **Step 4: Extract `parseAPNSAlert` helper and add `processNotificationAction()` to `PingOneMFA.swift`**

In `PingOneMFA/PingOneMFA/PingOneMFA.swift`, replace the inline APNS parsing at the top of `collectPush` with a call to a new private helper, and add the new method. 

**Replace** the body of `collectPush` (currently lines ~173–207) so it reads:

```swift
    public nonisolated static func collectPush(userInfo: [AnyHashable: Any]) async throws -> PushNotification {
        let (title, message) = parseAPNSAlert(from: userInfo)

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.processRemoteNotification(userInfo) { notificationObject, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError("Collect push failed: \(error.localizedDescription)"))
                } else if let notificationObject = notificationObject {
                    continuation.resume(returning: PushNotification(
                        notificationObject: notificationObject,
                        title: title,
                        message: message
                    ))
                } else {
                    continuation.resume(throwing: PingOneMFAError("Collect push returned no notification object"))
                }
            }
        }
    }
```

After `collectPush`, and before `collectMobilePayload`, add:

```swift
    /// Handles a push notification action triggered from the system notification banner.
    ///
    /// Call this from `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    ///
    /// - Parameters:
    ///   - identifier: `response.actionIdentifier` from `UNNotificationResponse`.
    ///   - authenticationMethod: The AMR value for the authentication method used (e.g. `"user"`, `"fpt"`).
    ///   - userInfo: `response.notification.request.content.userInfo`.
    /// - Returns: A `PushNotification` if the app must present approve/deny UI; `nil` if the SDK
    ///   handled the action internally and no further action is required.
    /// - Throws: `PingOneMFAError` if the SDK reports an error.
    public nonisolated static func processNotificationAction(
        identifier: String,
        authenticationMethod: String?,
        userInfo: [AnyHashable: Any]
    ) async throws -> PushNotification? {
        let (title, message) = parseAPNSAlert(from: userInfo)

        return try await withCheckedThrowingContinuation { continuation in
            PingOne.processRemoteNotificationAction(
                identifier,
                authenticationMethod: authenticationMethod,
                forRemoteNotification: userInfo
            ) { notificationObject, error in
                if let error = error {
                    continuation.resume(throwing: PingOneMFAError("Process notification action failed: \(error.localizedDescription)"))
                } else if let notificationObject = notificationObject {
                    continuation.resume(returning: PushNotification(
                        notificationObject: notificationObject,
                        title: title,
                        message: message
                    ))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
```

After `processNotificationAction`, and before `collectMobilePayload`, add the private helper:

```swift
    private nonisolated static func parseAPNSAlert(from userInfo: [AnyHashable: Any]) -> (title: String?, message: String?) {
        guard let aps = userInfo["aps"] as? [String: Any] else { return (nil, nil) }
        if let alert = aps["alert"] as? [String: Any] {
            return (alert["title"] as? String, alert["body"] as? String)
        } else if let alertString = aps["alert"] as? String {
            return (nil, alertString)
        }
        return (nil, nil)
    }
```

- [ ] **Step 5: Run all tests to confirm nothing regressed**

```bash
cd /Users/giorakrasilshchik/Documents/Projects/iOS/forgerock-ping-ios-sdk/PingOneMFA && \
xcodebuild test \
  -project PingOneMFA.xcodeproj \
  -scheme PingOneMFATests \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  2>&1 | grep -E "(PASS|FAIL|error:|Build succeeded|Build FAILED|Test Suite)"
```

Expected: all 23 tests pass, build succeeds.

- [ ] **Step 6: Commit**

```bash
git add PingOneMFA/PingOneMFA/PingOneMFA.swift \
        PingOneMFA/PingOneMFATests/MockPingOneMFA.swift \
        PingOneMFA/PingOneMFATests/PingOneMFATests.swift
git commit -m "feat(PingOneMFA): add processNotificationAction() and extract parseAPNSAlert helper"
```
