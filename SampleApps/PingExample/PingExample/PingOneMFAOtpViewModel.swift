//
//  PingOneMFAOtpViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOneMFA

/// ViewModel for the PingOne MFA OTP screen.
/// Fetches the current one-time passcode, displays a live countdown, and auto-refreshes
/// when the passcode expires.
@MainActor
class PingOneMFAOtpViewModel: ObservableObject {
    @Published var otpInfo: OtpCodeInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var countdown: Int = 0

    // One-shot task that sleeps until the current OTP expires, then calls loadOtp() again.
    private var refreshTask: Task<Void, Never>?
    // 1-Hz timer that decrements `countdown` for live display.
    private var countdownTimer: Timer?

    func loadOtp() async {
        guard !ConfigurationManager.shared.isPingOneMFAInitialized else {
            await fetchOtp()
            return
        }

        isLoading = true
        do {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
        } catch {
            errorMessage = "Failed to initialize PingOne MFA: \(error.localizedDescription)"
            isLoading = false
            return
        }
        await fetchOtp()
    }

    /// Stops timers and tasks. Call from the view's `onDisappear` to prevent resource leaks.
    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Private

    private func fetchOtp() async {
        // Cancel any in-flight refresh task before starting a new one.
        refreshTask?.cancel()
        refreshTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        isLoading = true
        errorMessage = nil

        do {
            let info = try await PingOneMFA.getOneTimePasscode()
            otpInfo = info
            countdown = info.secondsRemaining
            isLoading = false

            guard countdown > 0 else {
                return
            }

            // Start 1-Hz countdown timer for live display.
            startCountdownTimer()

            // Schedule one-shot refresh task that fires when the OTP expires.
            let sleepNanoseconds = UInt64(countdown) * 1_000_000_000
            refreshTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
                guard let self, !Task.isCancelled else { return }
                await self.loadOtp()
            }
        } catch {
            errorMessage = "Failed to fetch OTP: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                }
            }
        }
    }
}
