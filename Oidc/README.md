<p align="center">
  <a href="https://github.com/ForgeRock/ping-ios-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

`PingOidc` module provides a generic OIDC client that can be used with PingOne and ForgeRock platforms.

The `PingOidc` module follows the [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) specification and
provides a simple and easy-to-use API to interact with the OIDC server. It allows you to authenticate, retrieve the
access token, revoke the token, and sign out from the OIDC server.

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manager

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

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
