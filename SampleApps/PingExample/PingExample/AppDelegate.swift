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
import PingPush

/// AppDelegate to handle push notifications
/// - Note: Ensure that `PushClient` is initialized in `ConfigurationManager` before processing notifications.
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        requestNotificationPermissions()

        // Register for remote notifications
        application.registerForRemoteNotifications()

        return true
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

    // MARK: - Helper Methods

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

        // Process the notification through PushClient
        nonisolated(unsafe) let userInfoCopy = userInfo
        Task {
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

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Received push notification tap")
        print("Raw notification userInfo: \(userInfo)")

        // Process the notification through PushClient
        nonisolated(unsafe) let userInfoCopy = userInfo
        Task {
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

        completionHandler()
    }
}
