//
//  AppDelegate.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import UIKit
import UserNotifications
import AppTrackingTransparency
import PingPush
import PingOneMFA

/// AppDelegate to handle push notifications
/// - Note: Ensure that `PushClient` is initialized in `ConfigurationManager` before processing notifications.
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    /// Category identifiers registered by PingOneMFA, stored at launch for push routing.
    private var pingOneMFACategoryIdentifiers: Set<String> = []

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        requestNotificationPermissions()

        // ATT prompt only appears when the app is active. SwiftUI scene-based apps don't invoke
        // applicationDidBecomeActive on UIApplicationDelegate, so observe the notification directly.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Register for remote notifications
        application.registerForRemoteNotifications()

        // Register PingOneMFA notification categories so the system can deliver
        // actionable banner notifications (approve / deny actions).
        let pingOneMFACategories = PingOneMFA.getNotificationCategories()
        pingOneMFACategoryIdentifiers = Set(pingOneMFACategories.map { $0.identifier })
        UNUserNotificationCenter.current().setNotificationCategories(pingOneMFACategories)

        return true
    }

    @objc private func handleDidBecomeActive() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        requestTrackingAuthorization()
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Failed to request notification permissions: \(error.localizedDescription)")
            }

            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        }
    }

    private func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:    print("ATT: authorized")
            case .denied:        print("ATT: denied")
            case .restricted:    print("ATT: restricted")
            case .notDetermined: print("ATT: not determined")
            @unknown default:    print("ATT: unknown status \(status.rawValue)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Ensures PingOneMFA SDK is initialized.
    /// - Throws: Error if initialization fails.
    private func ensurePingOneMFAInitialized() async throws {
        if !ConfigurationManager.shared.isPingOneMFAInitialized {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
        }
    }

    /// Ensures PushClient is initialized and returns it
    /// - Returns: Initialized PushClient instance
    /// - Throws: Error if initialization fails
    private func getInitializedPushClient() async throws -> PushClient {
        if ConfigurationManager.shared.pushClient == nil {
            try await ConfigurationManager.shared.initializePushClient()
        }

        guard let client = ConfigurationManager.shared.pushClient else {
            throw NSError(
                domain: "AppDelegate",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize PushClient"]
            )
        }

        return client
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Received device token: \(tokenString)")

        // Store device token in PushClient
        Task {
            do {
                let client = try await getInitializedPushClient()
                let success = try await client.setDeviceToken(tokenString)
                if success {
                    print("Device token update completed successfully")
                } else {
                    print("Device token update completed with some failures - check logs for details")
                }
            } catch let error as NSError where error.domain == "AppDelegate" {
                print("Failed to update device token: PushClient not yet initialized. Will retry when client is ready.")
            } catch {
                print("Failed to update device token: \(error.localizedDescription)")
            }
        }

        // Register raw APNS token with PingOneMFA
        Task {
            do {
                try await ensurePingOneMFAInitialized()
                try await PingOneMFA.setDeviceToken(deviceToken)
                print("PingOneMFA device token registered successfully")
            } catch {
                print("Failed to register PingOneMFA device token: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("Received push notification in foreground")
        print("Raw notification userInfo: \(userInfo)")

        nonisolated(unsafe) let userInfoCopy = userInfo

        // Call immediately so the system knows how to present the banner.
        completionHandler([.banner, .sound, .badge])

        // Process in background — hold an assertion so the system doesn't suspend
        // before the async work completes.
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "willPresent-processing")

        Task {
            defer { UIApplication.shared.endBackgroundTask(bgTask) }
            do {
                try await ensurePingOneMFAInitialized()
                let pingOneMFANotification: MFAPushNotification? = try await PingOneMFA.processRemoteNotification(userInfo: userInfoCopy)
                if let pingOneMFANotification = pingOneMFANotification {
                    print("Processed PingOneMFA foreground push notification")
                    if pingOneMFANotification.pushType != .dry {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowPingOneMFANotification"),
                            object: nil,
                            userInfo: ["notification": pingOneMFANotification]
                        )
                    }
                }
            } catch {
                // PingOne SDK throws when the notification isn't a PingOne MFA push — fall through to PushClient.
                print("Failed to process PingOneMFA foreground push notification: \(error.localizedDescription)")
                do {
                    let client = try await getInitializedPushClient()

                    // Process the notification - PushClient automatically extracts APNs payload
                    if let pushNotification = try await client.processNotification(userInfo: userInfoCopy) {
                        print("Processed foreground push notification - ID: \(pushNotification.id), MessageID: \(pushNotification.messageId)")
                    } else {
                        print("Foreground notification was not processed (may be unsupported type)")
                    }
                } catch {
                    print("Failed to process foreground push notification: \(error.localizedDescription)")
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        print("Received push notification tap")
        print("Raw notification userInfo: \(userInfo)")

        nonisolated(unsafe) let userInfoCopy = userInfo
        let actionIdentifier = response.actionIdentifier

        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "didReceive-processing")

        // Route to PingOneMFA if the category matches one registered by PingOneMFA.
        if pingOneMFACategoryIdentifiers.contains(categoryIdentifier) {
            Task {
                defer {
                    completionHandler()
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
                do {
                    try await ensurePingOneMFAInitialized()
                    if let pingOneMFANotification: MFAPushNotification = try await PingOneMFA.processRemoteNotificationAction(
                        identifier: actionIdentifier,
                        authenticationMethod: "user",
                        userInfo: userInfoCopy
                    ) {
                        print("Processed PingOneMFA banner action: \(actionIdentifier)")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowPingOneMFANotification"),
                            object: nil,
                            userInfo: ["notification": pingOneMFANotification]
                        )
                    } else {
                        print("PingOneMFA handled notification action internally: \(actionIdentifier)")
                    }
                } catch {
                    print("Failed to process PingOneMFA notification action: \(error.localizedDescription)")
                }
            }
        } else {
            // Process the notification through PushClient (existing PingPush flow)
            Task {
                defer {
                    completionHandler()
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
                do {
                    let client = try await getInitializedPushClient()

                    // Process the notification - PushClient automatically extracts APNs payload
                    if let notification = try await client.processNotification(userInfo: userInfoCopy) {
                        print("Processed push notification successfully - ID: \(notification.id), MessageID: \(notification.messageId)")

                        // Navigate to Push Notifications view
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToPushNotifications"),
                            object: nil
                        )
                    } else {
                        print("Notification was not processed (may be unsupported type)")
                    }
                } catch {
                    print("Failed to process push notification: \(error.localizedDescription)")
                }
            }
        }
    }
}
