// 
//  ScenePhaseManager.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Combine
import UIKit // Required for UIScene notifications
import PingBrowser

class ScenePhaseManager: ObservableObject {
    // A property to track the current phase, which views can observe.
    @Published var currentPhase: String = "Unknown"
    
    // A set to store the notification subscriptions to manage their lifecycle.
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("ScenePhaseManager initialised. Subscribing to notifications.")

        // Subscribe to the notification for when the scene becomes active
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main) // Ensure updates happen on the main thread
            .sink { [weak self] _ in
                self?.currentPhase = "✅ Active"
                Task { @MainActor in
                    print("Scene is entering the foreground.")
                    if BrowserLauncher.currentBrowser.isInProgress {
                        print("RESETTING BROWSER")
                        BrowserLauncher.currentBrowser.reset()
                    }
                }
            }
            .store(in: &cancellables)

        // Subscribe to the notification for when the scene enters the background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.currentPhase = "BACKGROUND - Inactive"
                print("Scene has entered the background.")
            }
            .store(in: &cancellables)
    }

    deinit {
        print("ScenePhaseManager deinitialised. Cancellables will be released.")
    }
}
