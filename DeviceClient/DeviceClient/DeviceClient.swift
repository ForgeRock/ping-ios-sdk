//
//  DeviceClient.swift
//  DeviceClient
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOrchestrate

// MARK: - DeviceClientConfig

/// Configuration for DeviceClient
///
/// This struct encapsulates all configuration needed to initialize and operate the DeviceClient.
/// All properties are required to ensure proper authentication and routing of device management requests.
///
/// Example:
/// ```swift
/// let config = DeviceClientConfig(
///     serverUrl: "https://openam.example.com",
///     realm: "alpha",
///     cookieName: "iPlanetDirectoryPro",
///     ssoToken: "AQIC5w...",
///     httpClient: HttpClient()
/// )
/// ```
public struct DeviceClientConfig: Sendable {
    // MARK: Server Configuration
    
    /// The base URL of the server
    public let serverUrl: String
    
    /// The realm to use for device operations
    public let realm: String
    
    /// Cookie name for server configuration
    public let cookieName: String
    
    // MARK: Authentication
    
    /// The SSO (Single Sign-On) session token
    /// - Note: Token validity is not checked by DeviceClient; ensure token is valid before use
    public let ssoToken: String
    
    // MARK: Network Configuration
    
    /// The HTTP client used for network requests
    ///
    /// Default: Creates a new `HttpClient()` instance with default configuration
    public let httpClient: HttpClient
    
    // MARK: Initialization
    
    /// Initializes a new DeviceClientConfig
    ///
    /// Creates a complete configuration for the DeviceClient with all required parameters.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the server (e.g., `"https://openam.example.com"`)
    ///   - realm: The realm for device operations (e.g., `"alpha"`)
    ///   - cookieName: The header name for the SSO token (e.g., `"iPlanetDirectoryPro"`)
    ///   - ssoToken: The SSO session token for authentication
    ///   - httpClient: The HTTP client instance (default: `HttpClient()`)
    ///
    /// - Throws: Does not throw, but invalid URLs or tokens will cause runtime errors during API calls
    public init(
        serverUrl: String,
        realm: String = DeviceClientConstants.defaultRealm,
        cookieName: String = DeviceClientConstants.defaultCookieName,
        ssoToken: String,
        httpClient: HttpClient = HttpClient()
    ) {
        self.serverUrl = serverUrl
        self.realm = realm
        self.cookieName = cookieName
        self.ssoToken = ssoToken
        self.httpClient = httpClient
    }
}

// MARK: - DeviceClient

/// Client for managing user devices
///
/// `DeviceClient` provides a type-safe interface for managing various types of authentication
/// devices registered to a user.
///
/// ## Supported Device Types
///
/// ### Mutable (Full CRUD)
/// - **Oath**: TOTP/HOTP authentication devices
/// - **Push**: Push notification authentication devices
/// - **Bound**: Device binding for 2FA
/// - **Profile**: Device profiling information
/// - **WebAuthn**: WebAuthn/FIDO2 credentials
///
/// ## Usage
///
/// ```swift
/// // Initialize with configuration
/// let config = DeviceClientConfig(
///     serverUrl: "https://openam.example.com",
///     realm: "alpha",
///     cookieName: "iPlanetDirectoryPro",
///     ssoToken: token
/// )
/// let client = DeviceClient(config: config)
///
/// // Fetch devices
/// let result = await client.oath.get()
/// switch result {
/// case .success(let devices):
///     print("Found \(devices.count) devices")
/// case .failure(let error):
///     print("Error: \(error)")
/// }
///
/// // Update a device
/// if case .success(let devices) = await client.bound.get(),
///    var device = devices.first {
///     device.deviceName = "My Updated Device"
///     let updateResult = await client.bound.update(device)
///     if case .success = updateResult {
///         print("Device updated successfully")
///     }
/// }
///
/// // Delete a device
/// let deleteResult = await client.oath.delete(deviceToDelete)
/// if case .failure(let error) = deleteResult {
///     print("Failed to delete: \(error)")
/// }
/// ```
///
/// ## Error Handling
///
/// All operations return `Result` types:
///
/// ```swift
/// let result = await client.oath.get()
/// switch result {
/// case .success(let devices):
///     print("Fetched \(devices.count) devices")
/// case .failure(let error):
///     switch error {
///     case .requestFailed(let statusCode, let message):
///         print("Request failed: \(statusCode) - \(message)")
///     case .networkError(let error):
///         print("Network error: \(error)")
///     default:
///         print("Error: \(error.localizedDescription)")
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// `DeviceClient` is safe to use from any thread. All async methods are marked with appropriate
/// concurrency annotations and will execute on appropriate queues.
///
/// - Important: Ensure the SSO token in the configuration is valid before making requests
/// - Note: The client does not automatically refresh tokens; token management is the caller's responsibility
public class DeviceClient {
    // MARK: Properties
    
    /// The configuration for this client instance
    private let config: DeviceClientConfig
    
    /// Cached user ID to avoid repeated session info requests
    private var userId: String?
    
    // MARK: Initialization
    
    /// Initializes a new DeviceClient
    ///
    /// Creates a client instance configured for device management operations.
    ///
    /// - Parameter config: The configuration containing server details, credentials, and HTTP client
    ///
    /// Example:
    /// ```swift
    /// let config = DeviceClientConfig(
    ///     serverUrl: "https://openam.example.com",
    ///     realm: "alpha",
    ///     cookieName: "iPlanetDirectoryPro",
    ///     ssoToken: token
    /// )
    /// let client = DeviceClient(config: config)
    /// ```
    public init(config: DeviceClientConfig) {
        self.config = config
    }
    
    // MARK: Device Type Accessors
    
    /// Provides access to Oath devices
    ///
    /// Oath devices support TOTP (Time-based One-Time Password) and HOTP (HMAC-based One-Time Password)
    /// These devices are **mutable** - they support full CRUD operations.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Oath devices for the user
    /// - `update(_:)`: Update device properties (e.g., device name)
    /// - `delete(_:)`: Delete a specific Oath device
    ///
    /// Example:
    /// ```swift
    /// let result = await client.oath.get()
    /// switch result {
    /// case .success(let devices):
    ///     if var device = devices.first {
    ///         device.deviceName = "My Work Phone"
    ///         let updateResult = await client.oath.update(device)
    ///         if case .success = updateResult {
    ///             print("Device updated")
    ///         }
    ///
    ///         let deleteResult = await client.oath.delete(device)
    ///         if case .success = deleteResult {
    ///             print("Device deleted")
    ///         }
    ///     }
    /// case .failure(let error):
    ///     print("Error: \(error)")
    /// }
    /// ```
    public lazy var oath: any DeviceRepository<OathDevice> = {
        DeviceRepositoryImplementation<OathDevice>(endpoint: DeviceClientConstants.oathEndpoint, deviceClient: self)
    }()
    
    /// Provides access to Push devices
    ///
    /// Push devices support push notification-based authentication.
    /// These devices are **mutable** - they support full CRUD operations.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Push devices for the user
    /// - `update(_:)`: Update device properties (e.g., device name)
    /// - `delete(_:)`: Delete a specific Push device
    ///
    /// Example:
    /// ```swift
    /// let result = await client.push.get()
    /// switch result {
    /// case .success(let devices):
    ///     if var device = devices.first {
    ///         device.deviceName = "My Work Phone"
    ///         let updateResult = await client.push.update(device)
    ///         if case .success = updateResult {
    ///             print("Device updated")
    ///         }
    ///
    ///         let deleteResult = await client.push.delete(device)
    ///         if case .success = deleteResult {
    ///             print("Device deleted")
    ///         }
    ///     }
    /// case .failure(let error):
    ///     print("Error: \(error)")
    /// }
    /// ```
    public lazy var push: any DeviceRepository<PushDevice> = {
        DeviceRepositoryImplementation<PushDevice>(endpoint: DeviceClientConstants.pushEndpoint, deviceClient: self)
    }()
    
    /// Provides access to Bound devices
    ///
    /// Bound devices represent device bindings for two-factor authentication.
    /// These devices are **mutable** - they support full CRUD operations.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Bound devices for the user
    /// - `update(_:)`: Update device properties (e.g., device name)
    /// - `delete(_:)`: Delete a specific Bound device
    ///
    /// Example:
    /// ```swift
    /// let result = await client.bound.get()
    /// switch result {
    /// case .success(let devices):
    ///     if var device = devices.first {
    ///         device.deviceName = "My Work Phone"
    ///         let updateResult = await client.bound.update(device)
    ///         if case .success = updateResult {
    ///             print("Device updated")
    ///         }
    ///
    ///         let deleteResult = await client.bound.delete(device)
    ///         if case .success = deleteResult {
    ///             print("Device deleted")
    ///         }
    ///     }
    /// case .failure(let error):
    ///     print("Error: \(error)")
    /// }
    /// ```
    public lazy var bound: any DeviceRepository<BoundDevice> = {
        DeviceRepositoryImplementation<BoundDevice>(endpoint: DeviceClientConstants.bindingEndpoint, deviceClient: self)
    }()
    
    /// Provides access to Profile devices
    ///
    /// Profile devices store device profiling information including location and metadata.
    /// These devices are **mutable** - they support full CRUD operations.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Profile devices for the user
    /// - `update(_:)`: Update device properties (e.g., device name)
    /// - `delete(_:)`: Delete a specific Profile device
    ///
    /// Example:
    /// ```swift
    /// let result = await client.profile.get()
    /// switch result {
    /// case .success(let devices):
    ///     if var device = devices.first {
    ///         device.deviceName = "My iPhone"
    ///         let updateResult = await client.profile.update(device)
    ///         if case .success = updateResult {
    ///             print("Device updated")
    ///         }
    ///
    ///         let deleteResult = await client.profile.delete(device)
    ///         if case .success = deleteResult {
    ///             print("Device deleted")
    ///         }
    ///     }
    /// case .failure(let error):
    ///     print("Error: \(error)")
    /// }
    /// ```
    public lazy var profile: any DeviceRepository<ProfileDevice> = {
        DeviceRepositoryImplementation<ProfileDevice>(endpoint: DeviceClientConstants.profileEndpoint, deviceClient: self)
    }()
    
    /// Provides access to WebAuthn devices
    ///
    /// WebAuthn devices represent FIDO2/WebAuthn credentials for passwordless authentication.
    /// These devices are **mutable** - they support full CRUD operations.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all WebAuthn devices for the user
    /// - `update(_:)`: Update device properties (e.g., device name)
    /// - `delete(_:)`: Delete a specific WebAuthn device
    ///
    /// Example:
    /// ```swift
    /// let result = await client.webAuthn.get()
    /// switch result {
    /// case .success(let devices):
    ///     if var device = devices.first {
    ///         device.deviceName = "My YubiKey"
    ///         let updateResult = await client.webAuthn.update(device)
    ///         if case .success = updateResult {
    ///             print("Device updated")
    ///         }
    ///
    ///         let deleteResult = await client.webAuthn.delete(device)
    ///         if case .success = deleteResult {
    ///             print("Device deleted")
    ///         }
    ///     }
    /// case .failure(let error):
    ///     print("Error: \(error)")
    /// }
    /// ```
    public lazy var webAuthn: any DeviceRepository<WebAuthnDevice> = {
        DeviceRepositoryImplementation<WebAuthnDevice>(endpoint: DeviceClientConstants.webAuthnEndpoint, deviceClient: self)
    }()
    
    // MARK: - Internal Methods
    
    /// Fetches a list of devices from the server
    ///
    /// Generic method used by device type implementations to retrieve devices.
    ///
    /// - Parameter endpoint: The API endpoint to fetch devices from
    /// - Returns: An array of decoded devices of type `T`
    /// - Throws: `DeviceError` if the request fails or response cannot be decoded
    internal func fetchDevices<T: Decodable>(endpoint: String) async throws -> [T] {
        LogManager.logger.d("DeviceClient: Fetching devices from endpoint: \(endpoint)")
        
        let request = try await createGetRequest(for: endpoint)
        let response = try await executeRequest(request)
        
        guard response.status() == 200 else {
            LogManager.logger.e("DeviceClient: Failed to fetch devices. Status: \(response.status())", error: nil)
            throw DeviceError.requestFailed(statusCode: response.status(), message: "Failed to fetch devices")
        }
        
        do {
            let wrapper = try JSONDecoder().decode(DeviceResponse<T>.self, from: response.data)
            let devices = wrapper.result
            
            LogManager.logger.i("DeviceClient: Successfully fetched \(devices.count) devices")
            return devices
        } catch let error as DeviceError {
            throw error
        } catch {
            LogManager.logger.e("DeviceClient: Failed to decode devices", error: error)
            throw DeviceError.decodingFailed(error: error)
        }
    }
    
    /// Updates the given device on the server
    ///
    /// - Parameter device: The device to update with modified properties
    /// - Throws: `DeviceError` if the request fails
    internal func update(device: Device) async throws {
        LogManager.logger.d("DeviceClient: Updating device: \(device.id)")
        
        let request = try await createPutRequest(for: device)
        let response = try await executeRequest(request)
        
        guard response.status() == 200 else {
            LogManager.logger.e("DeviceClient: Failed to update device. Status: \(response.status())", error: nil)
            throw DeviceError.requestFailed(statusCode: response.status(), message: "Failed to update device")
        }
        
        LogManager.logger.i("DeviceClient: Successfully updated device: \(device.id)")
    }
    
    /// Deletes the given device from the server
    ///
    /// - Parameter device: The device to delete
    /// - Throws: `DeviceError` if the request fails
    internal func delete(device: Device) async throws {
        LogManager.logger.d("DeviceClient: Deleting device: \(device.id)")
        
        let request = try await createDeleteRequest(for: device)
        let response = try await executeRequest(request)
        
        guard response.status() == 200 || response.status() == 204 else {
            LogManager.logger.e("DeviceClient: Failed to delete device. Status: \(response.status())", error: nil)
            throw DeviceError.requestFailed(statusCode: response.status(), message: "Failed to delete device")
        }
        
        LogManager.logger.i("DeviceClient: Successfully deleted device: \(device.id)")
    }
    
    // MARK: - Private Methods
    
    /// Executes an HTTP request and returns the response
    ///
    /// - Parameter request: The request to execute
    /// - Returns: The HTTP response wrapped in `HttpResponse`
    /// - Throws: `DeviceError.networkError` if the request fails
    private func executeRequest(_ request: Request) async throws -> HttpResponse {
        do {
            let (data, urlResponse) = try await config.httpClient.sendRequest(request: request)
            return HttpResponse(data: data, response: urlResponse)
        } catch {
            LogManager.logger.e("DeviceClient: Request execution failed", error: error)
            throw DeviceError.networkError(error: error)
        }
    }
    
    /// Creates a GET request for fetching devices
    ///
    /// Constructs the URL, adds authentication headers, and configures the request
    /// for retrieving a list of devices from the specified endpoint.
    ///
    /// - Parameter endpoint: The device endpoint (e.g., "devices/2fa/oath")
    /// - Returns: A configured `Request` object ready for execution
    /// - Throws: `DeviceError.invalidUrl` if the URL cannot be constructed
    private func createGetRequest(for endpoint: String) async throws -> Request {
        let userId = try await fetchUserId()
        let urlString = "\(config.serverUrl)\(DeviceClientConstants.jsonPath)\(DeviceClientConstants.realmsPath)/\(config.realm)\(DeviceClientConstants.usersPath)/\(userId)/\(endpoint)"
        
        guard var components = URLComponents(string: urlString) else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        components.queryItems = [URLQueryItem(name: DeviceClientConstants.queryFilterKey, value: DeviceClientConstants.queryFilterValue)]
        
        guard let url = components.url else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        let request = Request(urlString: url.absoluteString)
        addAuthHeaders(to: request)
        request.method(Request.HTTPMethod.get)
        
        return request
    }
    
    /// Creates a PUT request for updating a device
    ///
    /// Constructs the URL, encodes the device as JSON, adds authentication headers,
    /// and configures the request for updating the specified device.
    ///
    /// - Parameter device: The device to update (must be encodable)
    /// - Returns: A configured `Request` object ready for execution
    /// - Throws: `DeviceError.invalidUrl` if the URL cannot be constructed
    /// - Throws: `DeviceError.encodingFailed` if the device cannot be encoded to JSON
    private func createPutRequest(for device: Device) async throws -> Request {
        let userId = try await fetchUserId()
        let urlString = "\(config.serverUrl)\(DeviceClientConstants.jsonPath)\(DeviceClientConstants.realmsPath)/\(config.realm)\(DeviceClientConstants.usersPath)/\(userId)/\(device.urlSuffix)/\(device.id)"
        
        guard URL(string: urlString) != nil else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        let data = try JSONEncoder().encode(device)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw DeviceError.encodingFailed(message: "Failed to encode device to JSON")
        }
        
        let request = Request(urlString: urlString)
        addAuthHeaders(to: request)
        if device.urlSuffix.hasSuffix(DeviceClientConstants.pushEndpoint) || device.urlSuffix.hasSuffix(DeviceClientConstants.oathEndpoint) {
            request.header(name: DeviceClientConstants.ifMatchHeader, value: DeviceClientConstants.ifMatchValue)
        }
        request.body(body: dictionary)
        request.method(Request.HTTPMethod.put)
        
        return request
    }
    
    /// Creates a DELETE request for removing a device
    ///
    /// Constructs the URL, adds authentication headers, and configures the request
    /// for deleting the specified device.
    ///
    /// - Parameter device: The device to delete
    /// - Returns: A configured `Request` object ready for execution
    /// - Throws: `DeviceError.invalidUrl` if the URL cannot be constructed
    private func createDeleteRequest(for device: Device) async throws -> Request {
        let userId = try await fetchUserId()
        let urlString = "\(config.serverUrl)\(DeviceClientConstants.jsonPath)\(DeviceClientConstants.realmsPath)/\(config.realm)\(DeviceClientConstants.usersPath)/\(userId)/\(device.urlSuffix)/\(device.id)"
        
        guard URL(string: urlString) != nil else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        let request = Request(urlString: urlString)
        addAuthHeaders(to: request)
        request.method(Request.HTTPMethod.delete)
        
        return request
    }
    
    /// Adds authentication headers to a request
    ///
    /// Configures the request with the SSO token and API version headers required
    /// for authentication with the ForgeRock/OpenAM server.
    ///
    /// - Parameters:
    ///   - request: The request to add headers to
    ///   - acceptAPIVersion: The API version to request (default: "resource=1.0")
    private func addAuthHeaders(to request: Request, acceptAPIVersion: String = DeviceClientConstants.resourceAPIVersion1_0) {
        request.header(name: config.cookieName, value: config.ssoToken)
        request.header(name: DeviceClientConstants.acceptAPIVersionHeader, value: acceptAPIVersion)
    }
    
    /// Fetches the user id from the session (with caching)
    /// - Returns: The user id
    private func fetchUserId() async throws -> String {
        // Return cached value if available
        if let userId = userId {
            return userId
        }
        
        LogManager.logger.d("DeviceClient: Fetching session username")
        
        let urlString = "\(config.serverUrl)\(DeviceClientConstants.jsonPath)\(DeviceClientConstants.realmsPath)/\(config.realm)\(DeviceClientConstants.sessionsPath)"
        guard var components = URLComponents(string: urlString) else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        components.queryItems = [URLQueryItem(name: DeviceClientConstants.actionKey, value: DeviceClientConstants.sessionInfoAction)]
        
        guard let url = components.url else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        let request = Request(urlString: url.absoluteString)
        addAuthHeaders(to: request, acceptAPIVersion: DeviceClientConstants.resourceAPIVersion2_1)
        request.method(Request.HTTPMethod.post)
        
        let response = try await executeRequest(request)
        
        guard response.status() == 200 else {
            LogManager.logger.e("DeviceClient: Failed to fetch session info. Status: \(response.status())", error: nil)
            throw DeviceError.requestFailed(statusCode: response.status(), message: "Failed to retrieve session information")
        }
        
        do {
            let session = try JSONDecoder().decode(Session.self, from: response.data)
            
            // Cache the user ID
            self.userId = session.username
            
            LogManager.logger.i("DeviceClient: Successfully retrieved username: \(session.username)")
            return session.username
        } catch {
            LogManager.logger.e("DeviceClient: Failed to decode session", error: error)
            throw DeviceError.decodingFailed(error: error)
        }
    }
}


// MARK: - DeviceRepositoryImplementation

/// Implementation of the `DeviceRepository` protocol for full CRUD devices
///
/// Provides GET, UPDATE, and DELETE operations for devices that support modification.
/// Used by Oath, Push, Bound, Profile, and WebAuthn device types.
///
/// - Note: This implementation is generic and can work with any device type conforming to `Device`
public struct DeviceRepositoryImplementation<R>: DeviceRepository where R: Device {
    /// The API endpoint for this device type
    var endpoint: String
    
    /// Reference to the parent DeviceClient for executing operations
    var deviceClient: DeviceClient
    
    /// Initializes a new mutable device implementation
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint for this device type
    ///   - deviceClient: The DeviceClient instance to use for operations
    public init(endpoint: String, deviceClient: DeviceClient) {
        self.endpoint = endpoint
        self.deviceClient = deviceClient
    }
    
    /// Retrieves all devices of this type for the user
    ///
    /// - Returns: A Result containing either the array of devices or an error
    public func get() async -> Result<[R], DeviceError> {
        do {
            let devices: [R] = try await deviceClient.fetchDevices(endpoint: endpoint)
            return .success(devices)
        } catch let error as DeviceError {
            return .failure(error)
        } catch {
            return .failure(.decodingFailed(error: error))
        }
    }
    
    /// Deletes the specified device from the server
    ///
    /// - Parameter device: The device to delete
    /// - Returns: A Result containing either success (true) or an error
    public func delete(_ device: R) async -> Result<Bool, DeviceError> {
        do {
            try await deviceClient.delete(device: device)
            return .success(true)
        } catch let error as DeviceError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error: error))
        }
    }
    
    /// Updates the specified device on the server
    ///
    /// - Parameter device: The device with updated properties
    /// - Returns: A Result containing either success (true) or an error
    public func update(_ device: R) async -> Result<Bool, DeviceError> {
        do {
            try await deviceClient.update(device: device)
            return .success(true)
        } catch let error as DeviceError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error: error))
        }
    }
}

private struct DeviceResponse<T: Decodable>: Decodable {
    let result: [T]
}

// MARK: - Session Model

/// Struct representing a user session.
struct Session: Codable {
    let username: String
    let universalId: String
    let realm: String
    let latestAccessTime: String
    let maxIdleExpirationTime: String
    let maxSessionExpirationTime: String
}

public enum DeviceClientConstants {
    // MARK: - URL Paths
    static let jsonPath = "/json"
    static let realmsPath = "/realms"
    static let usersPath = "/users"
    static let sessionsPath = "/sessions"
    
    // MARK: - Device Endpoints
    static let oathEndpoint = "devices/2fa/oath"
    static let pushEndpoint = "devices/2fa/push"
    static let bindingEndpoint = "devices/2fa/binding"
    static let profileEndpoint = "devices/profile"
    static let webAuthnEndpoint = "devices/2fa/webauthn"
    
    // MARK: - Query Parameters
    static let queryFilterKey = "_queryFilter"
    static let queryFilterValue = "true"
    static let actionKey = "_action"
    static let sessionInfoAction = "getSessionInfo"
    
    // MARK: - Headers
    static let acceptAPIVersionHeader = "Accept-API-Version"
    static let ifMatchHeader = "If-Match"
    static let ifMatchValue = "*"
    
    // MARK: - API Versions
    static let resourceAPIVersion1_0 = "resource=1.0"
    static let resourceAPIVersion2_1 = "resource=2.1"
    
    // MARK: - Default Values
    public static let defaultRealm = "root"
    public static let defaultCookieName = "iPlanetDirectoryPro"
}

