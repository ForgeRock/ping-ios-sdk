//
//  DeviceManagementViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingLogger
import PingOrchestrate
import PingStorage
import PingDeviceClient
import PingJourney
import PingOidc

/// Enum representing different device types for the UI
enum DeviceType: String, CaseIterable, Identifiable {
    case oath = "Oath"
    case push = "Push"
    case bound = "Bound"
    case profile = "Profile"
    case webAuthn = "WebAuthn"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .oath: return "timer"
        case .push: return "bell.fill"
        case .bound: return "link"
        case .profile: return "person.crop.circle"
        case .webAuthn: return "key.fill"
        }
    }
    
    var supportsUpdate: Bool {
        switch self {
        case .oath, .push:
            return false
        case .bound, .profile, .webAuthn:
            return true
        }
    }
}

/// ViewModel for managing devices
@MainActor
class DeviceManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var oathDevices: [OathDevice] = []
    @Published var pushDevices: [PushDevice] = []
    @Published var boundDevices: [BoundDevice] = []
    @Published var profileDevices: [ProfileDevice] = []
    @Published var webAuthnDevices: [WebAuthnDevice] = []
    
    @Published var isLoading = false
    @Published var isInitializing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedDeviceType: DeviceType = .oath
    
    // MARK: - Private Properties
    
    private var deviceClient: DeviceClient?
    private var cachedUserId: String?
    
    // MARK: - Initialization
    
    /// Initializes the DeviceClient with configuration
    /// - Returns: true if initialization succeeded, false otherwise
    @discardableResult
    func initialize() async -> Bool {
        isInitializing = true
        errorMessage = nil
        
        defer {
            isInitializing = false
        }
        
        // Load configuration
        let config = ConfigurationManager.shared.loadConfigurationViewModel()
        
        // Validate configuration
        guard let serverUrl = config.serverUrl, !serverUrl.isEmpty else {
            errorMessage = "Server URL is not configured. Please check settings."
            LogManager.logger.e("DeviceManagement: Missing server URL", error: nil)
            return false
        }
        
        guard let realm = config.realm, !realm.isEmpty else {
            errorMessage = "Realm is not configured. Please check settings."
            LogManager.logger.e("DeviceManagement: Missing realm", error: nil)
            return false
        }
        
        let cookieName = config.cookieName ?? "iPlanetDirectoryPro"
        
        // Fetch user ID
        guard let userId = await fetchUserId() else {
            errorMessage = "Unable to retrieve user information. Please ensure you are logged in."
            LogManager.logger.e("DeviceManagement: Failed to retrieve userId", error: nil)
            return false
        }
        
        // Cache user ID for future use
        cachedUserId = userId
        
        // Get session token
        guard let sessionToken = await ConfigurationManager.shared.journeySession?.value,
              !sessionToken.isEmpty else {
            errorMessage = "Session token not found. Please log in again."
            LogManager.logger.e("DeviceManagement: Missing or empty SSO token", error: nil)
            return false
        }
        
        // Create device client configuration
        let deviceConfig = DeviceClientConfig(
            serverUrl: serverUrl,
            realm: realm,
            cookieName: cookieName,
            userId: userId,
            ssoToken: sessionToken
        )
        
        // Initialize device client
        self.deviceClient = DeviceClient(config: deviceConfig)
        
        LogManager.logger.i("DeviceManagement: Successfully initialized with userId: \(userId)")
        return true
    }
    
    // MARK: - Device Operations
    
    /// Loads devices for the selected device type
    func loadDevices(for type: DeviceType) async {
        // Ensure client is initialized
        guard let client = deviceClient else {
            errorMessage = "Device client not initialized. Please try again."
            LogManager.logger.e("DeviceManagement: Attempted to load devices without initialization", error: nil)
            
            // Try to initialize
            if await initialize() {
                // Retry loading after successful initialization
                await loadDevices(for: type)
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        selectedDeviceType = type
        
        do {
            switch type {
            case .oath:
                oathDevices = try await client.oath.get()
                LogManager.logger.i("DeviceManagement: Loaded \(oathDevices.count) Oath devices")
                
            case .push:
                pushDevices = try await client.push.get()
                LogManager.logger.i("DeviceManagement: Loaded \(pushDevices.count) Push devices")
                
            case .bound:
                boundDevices = try await client.bound.get()
                LogManager.logger.i("DeviceManagement: Loaded \(boundDevices.count) Bound devices")
                
            case .profile:
                profileDevices = try await client.profile.get()
                LogManager.logger.i("DeviceManagement: Loaded \(profileDevices.count) Profile devices")
                
            case .webAuthn:
                webAuthnDevices = try await client.webAuthn.get()
                LogManager.logger.i("DeviceManagement: Loaded \(webAuthnDevices.count) WebAuthn devices")
            }
            
            successMessage = "Successfully loaded \(type.rawValue) devices"
        } catch let error as DeviceError {
            handleDeviceError(error, operation: "load devices")
        } catch {
            errorMessage = "Failed to load devices: \(error.localizedDescription)"
            LogManager.logger.e("DeviceManagement: Unexpected error loading devices", error: error)
        }
        
        isLoading = false
    }
    
    /// Deletes an Oath device
    func deleteOathDevice(_ device: OathDevice) async {
        await performDeviceOperation(operation: {
            try await self.deviceClient?.oath.delete(device)
            self.oathDevices.removeAll { $0.id == device.id }
        }, deviceName: device.deviceName, operationType: "delete", deviceType: "Oath")
    }
    
    /// Deletes a Push device
    func deletePushDevice(_ device: PushDevice) async {
        await performDeviceOperation(operation: {
            try await self.deviceClient?.push.delete(device)
            self.pushDevices.removeAll { $0.id == device.id }
        }, deviceName: device.deviceName, operationType: "delete", deviceType: "Push")
    }
    
    /// Deletes a Bound device
    func deleteBoundDevice(_ device: BoundDevice) async {
        await performDeviceOperation(operation: {
            try await self.deviceClient?.bound.delete(device)
            self.boundDevices.removeAll { $0.id == device.id }
        }, deviceName: device.deviceName, operationType: "delete", deviceType: "Bound")
    }
    
    /// Updates a Bound device
    func updateBoundDevice(_ device: BoundDevice, newName: String) async {
        await performDeviceOperation(operation: {
            var updatedDevice = device
            updatedDevice.deviceName = newName
            try await self.deviceClient?.bound.update(updatedDevice)
            
            if let index = self.boundDevices.firstIndex(where: { $0.id == device.id }) {
                self.boundDevices[index] = updatedDevice
            }
        }, deviceName: device.deviceName, operationType: "update", deviceType: "Bound")
    }
    
    /// Deletes a Profile device
    func deleteProfileDevice(_ device: ProfileDevice) async {
        await performDeviceOperation(operation: {
            try await self.deviceClient?.profile.delete(device)
            self.profileDevices.removeAll { $0.id == device.id }
        }, deviceName: device.deviceName, operationType: "delete", deviceType: "Profile")
    }
    
    /// Updates a Profile device
    func updateProfileDevice(_ device: ProfileDevice, newName: String) async {
        await performDeviceOperation(operation: {
            var updatedDevice = device
            updatedDevice.deviceName = newName
            try await self.deviceClient?.profile.update(updatedDevice)
            
            if let index = self.profileDevices.firstIndex(where: { $0.id == device.id }) {
                self.profileDevices[index] = updatedDevice
            }
        }, deviceName: device.deviceName, operationType: "update", deviceType: "Profile")
    }
    
    /// Deletes a WebAuthn device
    func deleteWebAuthnDevice(_ device: WebAuthnDevice) async {
        await performDeviceOperation(operation: {
            try await self.deviceClient?.webAuthn.delete(device)
            self.webAuthnDevices.removeAll { $0.id == device.id }
        }, deviceName: device.deviceName, operationType: "delete", deviceType: "WebAuthn")
    }
    
    /// Updates a WebAuthn device
    func updateWebAuthnDevice(_ device: WebAuthnDevice, newName: String) async {
        await performDeviceOperation(operation: {
            var updatedDevice = device
            updatedDevice.deviceName = newName
            try await self.deviceClient?.webAuthn.update(updatedDevice)
            
            if let index = self.webAuthnDevices.firstIndex(where: { $0.id == device.id }) {
                self.webAuthnDevices[index] = updatedDevice
            }
        }, deviceName: device.deviceName, operationType: "update", deviceType: "WebAuthn")
    }
    
    // MARK: - Helper Methods
    
    /// Generic method to perform device operations with consistent error handling
    private func performDeviceOperation(
        operation: () async throws -> Void,
        deviceName: String,
        operationType: String,
        deviceType: String
    ) async {
        guard deviceClient != nil else {
            errorMessage = "Device client not initialized"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await operation()
            successMessage = "Successfully \(operationType)d device: \(deviceName)"
            LogManager.logger.i("DeviceManagement: \(operationType.capitalized) \(deviceType) device: \(deviceName)")
        } catch let error as DeviceError {
            handleDeviceError(error, operation: "\(operationType) device")
        } catch {
            errorMessage = "Failed to \(operationType) device: \(error.localizedDescription)"
            LogManager.logger.e("DeviceManagement: Failed to \(operationType) \(deviceType) device", error: error)
        }
        
        isLoading = false
    }
    
    /// Handles DeviceError with appropriate user messages
    private func handleDeviceError(_ error: DeviceError, operation: String) {
        switch error {
        case .networkError:
            errorMessage = "Network error. Please check your connection and try again."
        case .requestFailed(let statusCode, _):
            if statusCode == 401 {
                errorMessage = "Session expired. Please log in again."
            } else if statusCode == 404 {
                errorMessage = "Device not found. It may have been already deleted."
            } else if statusCode >= 500 {
                errorMessage = "Server error. Please try again later."
            } else {
                errorMessage = "Failed to \(operation). Status code: \(statusCode)"
            }
        case .invalidToken:
            errorMessage = "Invalid session. Please log in again."
        case .decodingFailed:
            errorMessage = "Failed to process server response. Please try again."
        default:
            errorMessage = error.localizedDescription
        }
        LogManager.logger.e("DeviceManagement: Failed to \(operation)", error: error)
    }
    
    /// Refreshes the current device type
    func refresh() async {
        await loadDevices(for: selectedDeviceType)
    }
    
    /// Clears any messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    /// Gets the cached user ID if available
    func getCachedUserId() -> String? {
        return cachedUserId
    }
    
    // MARK: - User Info
    
    /// Fetches user information from the Journey/OIDC SDK
    /// - Returns: The user ID (sub claim) or nil if not available
    func fetchUserId() async -> String? {
        // Return cached value if available
        if let cached = cachedUserId {
            LogManager.logger.d("DeviceManagement: Using cached userId")
            return cached
        }
        
        // Get journey user
        guard let journeyUser = await ConfigurationManager.shared.journeyUser else {
            LogManager.logger.e("DeviceManagement: Journey user not available", error: nil)
            return nil
        }
        
        // Fetch user info without cache to get fresh data
        let userInfoResult = await journeyUser.userinfo(cache: false)
        
        switch userInfoResult {
        case .success(let userInfoDictionary):
            // Extract 'sub' claim as user ID
            if let userId = userInfoDictionary["sub"] as? String {
                LogManager.logger.i("DeviceManagement: Successfully retrieved userId from userinfo")
                cachedUserId = userId
                return userId
            } else {
                LogManager.logger.e("DeviceManagement: 'sub' claim not found in userinfo", error: nil)
                return nil
            }
            
        case .failure(let error):
            LogManager.logger.e("DeviceManagement: Failed to fetch userinfo", error: error)
            return nil
        }
    }
}
