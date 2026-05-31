[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingOidc

`PingOidc` module provides a generic OIDC client that can be used with PingOne and ForgeRock platforms.

The `PingOidc` module follows the [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) specification and
provides a simple and easy-to-use API to interact with the OIDC server. It allows you to authenticate, retrieve the
access token, revoke the token, and sign out from the OIDC server.

## Getting Started

### Prerequisites

- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingOidc` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingOidc', '~> <version>'
```

### Import the Module

```swift
import PingOidc
```

## Oidc Client Configuration

Basic Configuration, use `discoveryEndpoint` to lookup OIDC endpoints

```swift
// Create an OIDC client with the discovery endpoint, and other configurations
public let oidcLogin = OidcWebClient.createOidcWebClient { config in
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
    }
}

//Start the OIDC authentication flow
let state = try await oidcLogin.authorize { options in
    // Pass additional parameters
    options.additionalParameters = ["foo": "bar"]
}

// Handle the state
switch oidcLogin.state {
case .success( _ ):
    ...
case .failure(let error):
    ...
case .none:
    ...
}

// To retrieve the existing user
let oidcLoginUser = await oidcLogin.oidcLoginUser()

// To receive the access token
let token = await oidcLoginUser.token()

// Other methods
oidcLoginUser?.revoke()
oidcLoginUser?.logout()

// Setting the browser type and mode
public let oidcLogin = OidcWebClient.createOidcWebClient { config in
    // Set the browser mode(only the .login mode supported currently) and browser type.
    config.browserMode = .login
    config.browserType = .authSession
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
    }
}
```

By default, the SDK uses `KeychainStorage` (with `SecuredKeyEncryptor`) to store the token and `none` Logger is set,
however developers can override the storage and logger settings.

Basic Configuration with custom `storage` and `logger`

```swift
let config = OidcClientConfig()
config.logger = LogManager.standard //Log to console
config.storage = CustomStorage<Token>() //Use Custom Storage
//...

let ping = OidcClient(config: config)
```

## Advanced OIDC Configuration

Configurable attributes can be found under the [OIDC Spec](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)

```swift
let config = OidcClientConfig()
config.acrValues = "urn:acr:form"
config.loginHint = "test"
config.display = "test"
//...

let ping = OidcClient(config: config)
```

## Pushed Authorization Requests (PAR)

`PingOidc` supports [Pushed Authorization Requests (RFC 9126)](https://datatracker.ietf.org/doc/html/rfc9126). When PAR is enabled, authorization parameters are sent to the server via a POST request to the `pushed_authorization_request_endpoint` before the authorization redirect. The server returns a `request_uri` which is then used in the authorization URL instead of the full set of parameters.

To enable PAR, set the `par` property to `true` in the OIDC configuration:

```swift
let oidcLogin = OidcWebClient.createOidcWebClient { config in
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
        oidcValue.par = true // Enable Pushed Authorization Requests
    }
}
```

**Requirements:**
- The server's OpenID configuration (discovery document) must include a `pushed_authorization_request_endpoint`.
- If `par` is enabled but the discovery document does not include the PAR endpoint, the SDK falls back to the standard authorization flow automatically.

## Device Authorization Grant (RFC 8628)

`PingOidc` supports the [OAuth 2.0 Device Authorization Grant (RFC 8628)](https://datatracker.ietf.org/doc/html/rfc8628) for input-constrained devices (smart TVs, CLI tools) that can't directly open a browser. Use `OidcDeviceClient` to start a device flow, display the user code and verification URL, and poll for the access token.

```swift
let deviceClient = OidcDeviceClient.createOidcDeviceClient { config in
    config.clientId = "ClientID"
    config.scopes = ["openid", "profile", "email"]
    config.redirectUri = "org.forgerock.demo://oauth2redirect"
    config.discoveryEndpoint = "https://auth.example.com/.well-known/openid-configuration"
}

// Start the flow — returns an AsyncThrowingStream<DeviceFlowStatus, Error>
let stream = try await deviceClient.deviceAuthorization()

for try await status in stream {
    switch status {
    case .started(let response):
        // Display response.userCode and response.verificationUri (or response.verificationUriComplete)
        // to the user — for example as a QR code linking to verificationUriComplete.
        print("Visit \(response.verificationUri) and enter \(response.userCode)")
    case .polling(let pollCount, let pollInterval, let nextPollAt):
        // Optional: update UI with polling progress
        break
    case .success(let user):
        // Token has been saved to storage. `user` is an OidcUser ready to call .token() on.
        let token = await user.token()
    case .accessDenied:
        // The user denied the request.
        break
    case .expired:
        // The user code expired before the user authorized.
        break
    case .failure(let error):
        // Terminal error not covered by the RFC 8628 error codes.
        break
    }
}

// Optionally open the verification URL in SFSafariViewController on this device:
try await deviceClient.authorize(verificationUriComplete: response.verificationUriComplete ?? response.verificationUri)

// Retrieve the existing user (returns nil if no token has been saved):
let user = await deviceClient.user()

// Revoke the stored token:
await deviceClient.revoke()
```

**Requirements:**
- The server's OpenID configuration (discovery document) must include a `device_authorization_endpoint`.
- If the endpoint is missing, `deviceAuthorization()` throws `OidcError.unknown`.

The polling loop honors the server-supplied `interval` and increases it by 5 seconds on every `slow_down` response per RFC 8628. Network errors (`URLError`) trigger an exponential backoff (capped at 60 seconds) and the stream continues; the stream only finishes on `.success`, `.accessDenied`, `.expired`, or a non-recoverable error.

## Custom Agent

You can also provide a custom agent to launch the authorization request.
You can implement the `Agent` interface to create a custom agent.

```swift
protocol Agent<T> {
     associatedtype T
     
     func config() -> () -> T
     func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool
     func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode
}
```

Here is an example of creating a custom agent.

```swift
//Create a custom agent configuration
struct CustomAgentConfig {
    var config1 = "config1Value"
    var config2 = "config2Value"
}

class CustomAgent: Agent {
    func config() -> () -> CustomAgentConfig {
        return { CustomAgentConfig() }
    }
    
    func authorize(oidcConfig: Oidc.OidcConfig<T>) async throws -> Oidc.AuthCode {
        oidcConfig.config.config2 //Access the agent configuration
        oidcConfig.oidcClientConfig.openId?.endSessionEndpoint //Access the oidcClientConfig
        return AuthCode(code: "TestAgent", codeVerifier: "")
    }
    
    func endSession(oidcConfig: Oidc.OidcConfig<CustomAgentConfig>, idToken: String) async throws -> Bool {
        //Logout session with idToken
        oidcConfig.config.config1 //Access the agent configuration
        oidcConfig.oidcClientConfig.openId?.endSessionEndpoint //Access the oidcClientConfig
        return true
    }
}

let config = OidcClientConfig()
config.updateAgent(CustomAgent())
//...

let ping = OidcClient(config: config)

```

## Migration Guide

### Migrating to `OidcWebClient` (from 2.0.0)

The following classes and methods have been renamed for consistency starting from version 2.0.0:

| Old Name | New Name |
|----------|----------|
| `OidcWeb` | `OidcWebClient` |
| `OidcWebConfig` | `OidcWebClientConfig` |
| `createOidcWeb` | `createOidcWebClient` |

**Before:**
```swift
let oidcLogin = OidcWeb.createOidcWeb { config in
    // configuration
}
```

**After:**
```swift
let oidcLogin = OidcWebClient.createOidcWebClient { config in
    // configuration
}
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
