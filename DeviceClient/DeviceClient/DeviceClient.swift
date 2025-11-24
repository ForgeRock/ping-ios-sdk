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
///     userId: "userid",
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
    
    /// The user ID for whom to manage devices
    public let userId: String
    
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
    ///   - userId: The user ID for device management (e.g., `"demo"`)
    ///   - ssoToken: The SSO session token for authentication
    ///   - httpClient: The HTTP client instance (default: `HttpClient()`)
    ///
    /// - Throws: Does not throw, but invalid URLs or tokens will cause runtime errors during API calls
    public init(
        serverUrl: String,
        realm: String,
        cookieName: String,
        userId: String,
        ssoToken: String,
        httpClient: HttpClient = HttpClient()
    ) {
        self.serverUrl = serverUrl
        self.realm = realm
        self.cookieName = cookieName
        self.userId = userId
        self.ssoToken = ssoToken
        self.httpClient = httpClient
    }
}

// MARK: - DeviceClient

/// Client for managing user devices
///
/// `DeviceClient` provides a type-safe interface for managing various types of authentication
/// devices registered to a user. It supports both immutable devices (read/delete only) and
/// mutable devices (read/update/delete).
///
/// ## Supported Device Types
///
/// ### Immutable (Read/Delete Only)
/// - **Oath**: TOTP/HOTP authentication devices
/// - **Push**: Push notification authentication devices
///
/// ### Mutable (Full CRUD)
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
///     userId: "demo",
///     ssoToken: token
/// )
/// let client = DeviceClient(config: config)
///
/// // Fetch devices
/// let oathDevices = try await client.oath.get()
///
/// // Update a device (mutable types only)
/// var device = boundDevices.first!
/// device.deviceName = "My Updated Device"
/// try await client.bound.update(device)
///
/// // Delete a device
/// try await client.oath.delete(deviceToDelete)
/// ```
///
/// ## Error Handling
///
/// All operations throw `DeviceError` on failure:
///
/// ```swift
/// do {
///     let devices = try await client.oath.get()
/// } catch let error as DeviceError {
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
    ///     userId: "demo",
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
    /// authentication. These devices are **immutable** - they support read and delete operations only.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Oath devices for the user
    /// - `delete(_:)`: Delete a specific Oath device
    ///
    /// Example:
    /// ```swift
    /// let devices = try await client.oath.get()
    /// try await client.oath.delete(devices.first!)
    /// ```
    public lazy var oath: any ImmutableDevice<OathDevice> = {
        ImmutableDeviceImplementation<OathDevice>(endpoint: "devices/2fa/oath", deviceClient: self)
    }()
    
    /// Provides access to Push devices
    ///
    /// Push devices support push notification-based authentication.
    /// These devices are **immutable** - they support read and delete operations only.
    ///
    /// Supported operations:
    /// - `get()`: Retrieve all Push devices for the user
    /// - `delete(_:)`: Delete a specific Push device
    ///
    /// Example:
    /// ```swift
    /// let devices = try await client.push.get()
    /// try await client.push.delete(devices.first!)
    /// ```
    public lazy var push: any ImmutableDevice<PushDevice> = {
        ImmutableDeviceImplementation<PushDevice>(endpoint: "devices/2fa/push", deviceClient: self)
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
    /// let devices = try await client.bound.get()
    ///
    /// var device = devices.first!
    /// device.deviceName = "My Work Phone"
    /// try await client.bound.update(device)
    ///
    /// try await client.bound.delete(device)
    /// ```
    public lazy var bound: any MutableDevice<BoundDevice> = {
        MutableDeviceImplementation<BoundDevice>(endpoint: "devices/2fa/binding", deviceClient: self)
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
    /// let devices = try await client.profile.get()
    ///
    /// var device = devices.first!
    /// device.deviceName = "My iPhone"
    /// try await client.profile.update(device)
    ///
    /// try await client.profile.delete(device)
    /// ```
    public lazy var profile: any MutableDevice<ProfileDevice> = {
        MutableDeviceImplementation<ProfileDevice>(endpoint: "devices/profile", deviceClient: self)
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
    /// let devices = try await client.webAuthn.get()
    ///
    /// var device = devices.first!
    /// device.deviceName = "My YubiKey"
    /// try await client.webAuthn.update(device)
    ///
    /// try await client.webAuthn.delete(device)
    /// ```
    public lazy var webAuthn: any MutableDevice<WebAuthnDevice> = {
        MutableDeviceImplementation<WebAuthnDevice>(endpoint: "devices/2fa/webauthn", deviceClient: self)
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
            let json = try response.json()
            guard let resultArray = json["result"] as? [[String: Any]] else {
                throw DeviceError.invalidResponse(message: "Missing 'result' array in response")
            }
            
            let resultData = try JSONSerialization.data(withJSONObject: resultArray, options: [])
            let devices = try JSONDecoder().decode([T].self, from: resultData)
            
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
        let urlString = "\(config.serverUrl)/json/realms/\(config.realm)/users/\(config.userId)/\(endpoint)"
        
        guard var components = URLComponents(string: urlString) else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        components.queryItems = [URLQueryItem(name: "_queryFilter", value: "true")]
        
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
        let urlString = "\(config.serverUrl)/json/realms/\(config.realm)/users/\(config.userId)/\(device.urlSuffix)/\(device.id)"
        
        guard URL(string: urlString) != nil else {
            throw DeviceError.invalidUrl(url: urlString)
        }
        
        let data = try JSONEncoder().encode(device)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw DeviceError.encodingFailed(message: "Failed to encode device to JSON")
        }
        
        let request = Request(urlString: urlString)
        addAuthHeaders(to: request)
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
        let urlString = "\(config.serverUrl)/json/realms/\(config.realm)/users/\(config.userId)/\(device.urlSuffix)/\(device.id)"
        
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
    private func addAuthHeaders(to request: Request, acceptAPIVersion: String = "resource=1.0") {
        request.header(name: config.cookieName, value: config.ssoToken)
        request.header(name: "Accept-API-Version", value: acceptAPIVersion)
    }
}

// MARK: - ImmutableDeviceImplementation

/// Implementation of the `ImmutableDevice` protocol for read-only devices
///
/// Provides GET and DELETE operations for devices that do not support updates.
/// Used by Oath and Push device types.
///
/// - Note: This implementation is generic and can work with any device type conforming to `Device`
public struct ImmutableDeviceImplementation<R>: ImmutableDevice where R: Device {
    /// The API endpoint for this device type
    var endpoint: String
    
    /// Reference to the parent DeviceClient for executing operations
    var deviceClient: DeviceClient
    
    /// Initializes a new immutable device implementation
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
    /// - Returns: An array of devices
    /// - Throws: `DeviceError` if the request fails or cannot be decoded
    public func get() async throws -> [R] {
        try await deviceClient.fetchDevices(endpoint: endpoint)
    }
    
    /// Deletes the specified device from the server
    ///
    /// - Parameter device: The device to delete
    /// - Throws: `DeviceError` if the request fails
    public func delete(_ device: R) async throws {
        try await deviceClient.delete(device: device)
    }
}

// MARK: - MutableDeviceImplementation

/// Implementation of the `MutableDevice` protocol for full CRUD devices
///
/// Provides GET, UPDATE, and DELETE operations for devices that support modification.
/// Used by Bound, Profile, and WebAuthn device types.
///
/// - Note: This implementation is generic and can work with any device type conforming to `Device`
public struct MutableDeviceImplementation<R>: MutableDevice where R: Device {
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
    /// - Returns: An array of devices
    /// - Throws: `DeviceError` if the request fails or cannot be decoded
    public func get() async throws -> [R] {
        try await deviceClient.fetchDevices(endpoint: endpoint)
    }
    
    /// Deletes the specified device from the server
    ///
    /// - Parameter device: The device to delete
    /// - Throws: `DeviceError` if the request fails
    public func delete(_ device: R) async throws {
        try await deviceClient.delete(device: device)
    }
    
    /// Updates the specified device on the server
    ///
    /// - Parameter device: The device with updated properties
    /// - Throws: `DeviceError` if the request fails
    public func update(_ device: R) async throws {
        try await deviceClient.update(device: device)
    }
}
