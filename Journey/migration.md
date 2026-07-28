# Swift Legacy to Modern Migration Examples

This guide provides comprehensive examples for migrating from the Legacy ForgeRock iOS SDK (FRAuth) to the Modern Ping SDK for iOS (Journey/DaVinci). The examples are based on real-world implementations and demonstrate the key architectural and API changes.

## Migration Overview

The Modern Ping SDK represents a fundamental architectural shift from callback-based to async/await patterns, with a more modular and type-safe design. Key changes include:

- **Async/Await**: All network operations use Swift's native concurrency instead of completion handlers
- **Workflow Pattern**: Journey/DaVinci use a workflow orchestration engine with explicit node states
- **Modular Architecture**: Clear separation between core, plugins, and feature modules
- **Type Safety**: Explicit node types (ContinueNode, SuccessNode, FailureNode, ErrorNode)
- **Callback-Specific Properties**: Each callback type has specific properties (e.g., `name`, `password`, `selectedIndex`) instead of generic `value`/`setValue()`
- **Modern Swift**: Full Swift 6 concurrency support with Sendable conformance
- **Minimum Requirements**: iOS 16.0+ (up from iOS 12.0+ in Legacy SDK), Swift 6.0+

## Quick Reference

| Legacy SDK | Modern SDK | Notes |
|------------|------------|-------|
| `FRAuth.start(options:)` | `Journey.createJourney { config in ... }` | Configuration now declarative |
| `FRSession.authenticate()` | `journey.start()` | Returns explicit node types |
| `Node.next()` completion | `await node.next()` | Async/await instead of callbacks |
| `FRUser.currentUser` | `await journey.journeyUser()` | Async property access |
| `WebAuthnRegistrationCallback` | `FidoRegistrationCallback` | Renamed for clarity |
| `WebAuthnAuthenticationCallback` | `FidoAuthenticationCallback` | Renamed for clarity |
| `SelectIdPCallback` | `SelectIdpCallback` | Case change |
| `callback.setValue(value)` | `callback.name` / `callback.password` / `callback.selectedIndex` | Specific properties per callback type |
| N/A (Legacy used Error object) | `failureNode.cause` | New property in Modern SDK |
| N/A (Legacy used Error object) | `errorNode.message` | New property in Modern SDK |
| `Node` | `ContinueNode` | Class changed |

---

## Example: Swift Package Manager Migration

### Legacy Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/ForgeRock/forgerock-ios-sdk",
        from: "4.0.0"
    )
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "FRAuth", package: "forgerock-ios-sdk"),
            .product(name: "FRAuthenticator", package: "forgerock-ios-sdk"),
            .product(name: "FRDeviceBinding", package: "forgerock-ios-sdk"),
            .product(name: "FRProximity", package: "forgerock-ios-sdk"),
            .product(name: "FRGoogleSignIn", package: "forgerock-ios-sdk"),
            .product(name: "FRFacebookSignIn", package: "forgerock-ios-sdk"),
            .product(name: "PingProtect", package: "forgerock-ios-sdk"),
        ]
    )
]
```

### Modern Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/ForgeRock/ping-ios-sdk",
        from: "2.1.0"
    )
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            // Core authentication
            .product(name: "PingOrchestrate", package: "ping-ios-sdk"),
            .product(name: "PingJourney", package: "ping-ios-sdk"),
            .product(name: "PingOidc", package: "ping-ios-sdk"),
            
            // Device management
            .product(name: "PingDeviceProfile", package: "ping-ios-sdk"),
            .product(name: "PingDeviceClient", package: "ping-ios-sdk"),
            .product(name: "PingDeviceId", package: "ping-ios-sdk"),
            
            // MFA and Security
            .product(name: "PingOath", package: "ping-ios-sdk"),
            .product(name: "PingPush", package: "ping-ios-sdk"),
            .product(name: "PingFido", package: "ping-ios-sdk"),
            .product(name: "PingBinding", package: "ping-ios-sdk"),
            
            // External Identity Providers
            .product(name: "PingExternalIdPApple", package: "ping-ios-sdk"),
            .product(name: "PingExternalIdPGoogle", package: "ping-ios-sdk"),
            .product(name: "PingExternalIdPFacebook", package: "ping-ios-sdk"),
            
            // Security
            .product(name: "PingProtect", package: "ping-ios-sdk"),
            .product(name: "PingReCaptchaEnterprise", package: "ping-ios-sdk"),
        ]
    )
]
```

**Note**: The Modern SDK requires iOS 16.0+ as the minimum deployment target. Update your platform requirement:

```swift
platforms: [
    .iOS(.v16)  // Updated from .iOS(.v12) in Legacy SDK
]
```

## Example: SDK Import Changes

### Legacy

```swift
import FRAuth
import FRCore
import FRAuthenticator
import FRDeviceBinding
import FRProximity
import FRGoogleSignIn
import FRFacebookSignIn
import PingProtect
import FRCaptchaEnterprise
```

### Modern

```swift
import PingOrchestrate
import PingJourney
import PingOidc
import PingDeviceProfile
import PingDeviceClient
import PingDeviceId
import PingBinding
import PingOath
import PingPush
import PingFido
import PingExternalIdP
import PingExternalIdPApple
import PingExternalIdPGoogle
import PingExternalIdPFacebook
import PingProtect
import PingReCaptchaEnterprise
```

## Example: SDK Initialization

### Legacy

```swift
// Using FROptions for programmatic configuration
let options = FROptions(
    url: "https://openam.example.com/am",
    realm: "alpha",
    cookieName: "iPlanetDirectoryPro",
    authServiceName: "Login",
    oauthClientId: "iOSClient",
    oauthRedirectUri: "com.example.app:/oauth2redirect",
    oauthScope: "openid profile email"
)

do {
    try FRAuth.start(options: options)
    print("SDK initialized successfully")
    FRLog.setLogLevel([.error, .network])
} catch {
    print("Error starting SDK: \(error)")
}

// Or with plist configuration
do {
    try FRAuth.start()
    // SDK initialized with FRAuthConfig.plist configuration
} catch {
    print("Error starting SDK: \(error)")
}
```

### Modern

```swift
let journey = Journey.createJourney { config in
    config.logger = LogManager.standard
    
    config.serverUrl = "https://openam.example.com/am"
    config.realm = "alpha"
    config.cookie = "iPlanetDirectoryPro"
    config.timeout = 60
    
    // OIDC module configuration
    config.module(PingJourney.OidcModule.config) { oidcConfig in
        oidcConfig.clientId = "iOSClient"
        oidcConfig.discoveryEndpoint = "https://openam.example.com/am/oauth2/alpha/.well-known/openid-configuration"
        oidcConfig.scopes = ["openid", "profile", "email"]
        oidcConfig.redirectUri = "com.example.app:/oauth2redirect"
    }
}
```

## Example: Starting Authentication

### Legacy

```swift
let journeyName = "Login"
FRSession.authenticate(authIndexValue: journeyName) { (token: Token?, node, error) in
    if let error = error {
        print("Error: \(error)")
    } else if let token = token {
        print("Authentication successful with token")
    } else if let node = node {
        // Process node callbacks
        self.handleNode(node)
    }
}
```

### Modern

```swift
let journeyName = "Login"
let node = await journey.start(journeyName)

switch node {
case let continueNode as ContinueNode:
    // Process callbacks
    handleCallbacks(continueNode)
    
case let successNode as SuccessNode:
    print("Authentication successful")
    
case let failureNode as FailureNode:
    print("Authentication failed: \(failureNode.cause)")
    
case let errorNode as ErrorNode:
    print("Error: \(errorNode.message)")
    
default:
    break
}
```

## Example: Move to Next Node in the Journey

### Legacy

```swift
func handleNode(_ node: Node) {
    // Set callback values
    for callback in node.callbacks {
        if let nameCallback = callback as? NameCallback {
            nameCallback.setValue("username")
        } else if let passwordCallback = callback as? PasswordCallback {
            passwordCallback.setValue("password")
        }
    }
    
    // Submit node
    node.next { (token: Token?, node, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let token = token {
            print("Authentication successful")
        } else if let node = node {
            self.handleNode(node)
        }
    }
}
```

### Modern

```swift
func handleCallbacks(_ node: ContinueNode) async {
    // Set callback values
    for callback in node.callbacks {
        if let nameCallback = callback as? NameCallback {
            nameCallback.name = "username"
        } else if let passwordCallback = callback as? PasswordCallback {
            passwordCallback.password = "password"
        }
    }
    
    // Submit node
    let nextNode = await node.next()
    
    switch nextNode {
    case let continueNode as ContinueNode:
        await handleCallbacks(continueNode)
        
    case let successNode as SuccessNode:
        print("Authentication successful")
        
    case let failureNode as FailureNode:
        print("Authentication failed")
        
    case let errorNode as ErrorNode:
        print("Error occurred")
        
    default:
        break
    }
}
```

## Example: User Logout

### Legacy

```swift
// Logout session
FRSession.currentSession?.logout()

// Or logout FRUser (revokes OAuth2 tokens and session)
FRUser.currentUser?.logout()
```

### Modern

```swift
// Logout user (revokes OAuth2 tokens and session)
await journey.journeyUser()?.logout()
```

## Example: WebAuthn Registration Callback

### Legacy

```swift
if let registrationCallback = callback as? WebAuthnRegistrationCallback {
    registrationCallback.delegate = self
    let deviceName = UIDevice.current.name
    
    // Note: The `node` parameter is optional
    // If provided, SDK automatically sets error outcome or attestation to designated HiddenValueCallback
    registrationCallback.register(
        node: node,
        deviceName: deviceName,
        usePasskeysIfAvailable: true,
        onSuccess: { attestation in
            print("Registration successful")
            // Submit the Node using node.next()
            node.next { (token: Token?, node, error) in
                self.handleNode(token: token, node: node, error: error)
            }
        },
        onError: { error in
            print("Registration failed: \(error)")
            // Submit the Node using node.next()
            node.next { (token: Token?, node, error) in
                self.handleNode(token: token, node: node, error: error)
            }
        }
    )
}

// Implement delegate protocol
extension MyViewController: PlatformAuthenticatorRegistrationDelegate {
    func excludeCredentialDescriptorConsent(consentCallback: @escaping WebAuthnUserConsentCallback) {}
    
    func createNewCredentialConsent(
        keyName: String,
        rpName: String,
        rpId: String?,
        userName: String,
        userDisplayName: String,
        consentCallback: @escaping WebAuthnUserConsentCallback
    ) {}
}
```

### Modern

```swift
if let fidoCallback = callback as? FidoRegistrationCallback {
    let deviceName = "MyDevice"
    
    // window is from your UIViewController's view.window
    let result = await fidoCallback.register(deviceName: deviceName, window: window)
    
    switch result {
    case .success(let registrationData):
        print("Registration successful: \(registrationData)")
    case .failure(let error):
        print("Registration failed: \(error)")
    }
}
```

## Example: WebAuthn Authentication Callback

### Legacy

```swift
if let authenticationCallback = callback as? WebAuthnAuthenticationCallback {
    authenticationCallback.delegate = self
    
    // Note: The `node` parameter is optional
    // If provided, SDK automatically sets assertion to designated HiddenValueCallback
    authenticationCallback.authenticate(
        node: node,
        usePasskeysIfAvailable: true,
        onSuccess: { assertion in
            print("Authentication successful")
            // Submit the Node using node.next()
            node.next { (token: Token?, node, error) in
                self.handleNode(token: token, node: node, error: error)
            }
        },
        onError: { error in
            print("Authentication failed: \(error)")
            // Submit the Node using node.next()
            node.next { (token: Token?, node, error) in
                self.handleNode(token: token, node: node, error: error)
            }
        }
    )
}

// Implement delegate protocol
extension MyViewController: PlatformAuthenticatorAuthenticationDelegate {
    func localKeyExistsConsent(keyName: String, consentCallback: @escaping WebAuthnUserConsentCallback) {}
    
    func selectCredential(
        keyNames: [String],
        selectionCallback: @escaping WebAuthnCredentialSelectionCallback
    ) {}
}
```

### Modern

```swift
if let fidoCallback = callback as? FidoAuthenticationCallback {
    // window is from your UIViewController's view.window
    let result = await fidoCallback.authenticate(window: window)
    
    switch result {
    case .success(let authData):
        print("Authentication successful: \(authData)")
    case .failure(let error):
        print("Authentication failed: \(error)")
    }
}
```

## Example: Retrieving User Profile Information

### Legacy

```swift
FRUser.currentUser?.getUserInfo { (userInfo, error) in
    if let error = error {
        print("Error fetching user info: \(error)")
    } else if let userInfo = userInfo {
        print("User info: \(userInfo)")
        print("Name: \(userInfo.name ?? "N/A")")
        print("Email: \(userInfo.email ?? "N/A")")
    }
}
```

### Modern

```swift
if let user = await journey.journeyUser() {
    // userinfo() returns Result<UserInfo, OidcError>
    let result = await user.userinfo(cache: false)
    
    switch result {
    case .success(let userInfo):
        print("User info: \(userInfo)")
        print("Name: \(userInfo["name"] ?? "N/A")")
        print("Email: \(userInfo["email"] ?? "N/A")")
    case .failure(let error):
        print("Error fetching user info: \(error)")
    }
}
```

## Example: Retrieving Access Token

### Legacy

```swift
if let currentUser = FRUser.currentUser,
   let accessToken = currentUser.token {
    print("Access Token: \(accessToken.value)")
    print("Expires In: \(accessToken.expiresIn)")
    print("Token Type: \(accessToken.tokenType)")
}
```

### Modern

```swift
if let user = await journey.journeyUser() {
    let result = await user.token()
    
    switch result {
    case .success(let token):
        print("Access Token: \(token.value)")
        print("Expires In: \(token.expiresIn ?? 0)")
        print("Token Type: \(token.tokenType)")
    case .failure(let error):
        print("Error retrieving token: \(error)")
    }
}
```

## Example: Revoke Access Token

### Legacy

```swift
FRUser.currentUser?.revokeAccessToken { (user, error) in
    if let error = error {
        print("Error revoking token: \(error)")
    } else {
        print("Access token revoked successfully")
    }
}
```

### Modern

```swift
if let user = await journey.journeyUser() {
    // revoke() does not return a value or throw errors
    await user.revoke()
    print("Access token revoked successfully")
}
```

## Example: Refresh Access Token

### Legacy

```swift
FRUser.currentUser?.refresh { (user, error) in
    if let error = error {
        print("Error refreshing token: \(error)")
    } else if let user = user {
        print("Token refreshed successfully")
        print("New Access Token: \(user.token?.value ?? "N/A")")
    }
}
```

### Modern

```swift
if let user = await journey.journeyUser() {
    // refresh() returns Result<Token, OidcError>
    let result = await user.refresh()
    
    switch result {
    case .success(let newToken):
        print("Token refreshed successfully")
        print("New Access Token: \(newToken.value)")
    case .failure(let error):
        print("Error refreshing token: \(error)")
    }
}
```

## Example: Centralized Login (Browser-based OIDC)

### Legacy

```swift
import AuthenticationServices

FRUser.browser()?
    .set(presentingViewController: self)
    .set(browserType: .authSession)
    .build()
    .login { (user, error) in
        if let error = error {
            print("Login error: \(error)")
        } else if let user = user {
            print("Login successful")
            print("Access Token: \(user.token?.value ?? "N/A")")
        }
    }
```

### Modern

```swift
import PingOidc

let oidcLogin = OidcWeb.createOidcWeb { config in
    config.browserMode = .login
    config.browserType = .authSession
    config.logger = LogManager.standard
    
    config.module(PingOidc.OidcModule.config) { oidcConfig in
        oidcConfig.clientId = "iOSClient"
        oidcConfig.discoveryEndpoint = "https://openam.example.com/am/oauth2/alpha/.well-known/openid-configuration"
        oidcConfig.scopes = ["openid", "profile", "email"]
        oidcConfig.redirectUri = "com.example.app:/oauth2redirect"
    }
}

do {
    let user = try await oidcLogin.authorize(presentingViewController: self)
    print("Login successful")
    
    let result = await user.token()
    switch result {
    case .success(let token):
        print("Access Token: \(token.value)")
    case .failure(let error):
        print("Error retrieving token: \(error)")
    }
} catch {
    print("Login error: \(error)")
}
```

## Example: Centralized Logout (Browser-based OIDC)

### Legacy

```swift
FRUser.browser()?
    .set(presentingViewController: self)
    .build()
    .logout { (user, error) in
        if let error = error {
            print("Logout error: \(error)")
        } else {
            print("Logout successful")
        }
    }
```

### Modern

```swift
if let user = await oidcLogin.oidcLoginUser() {
    // logout() does not throw errors
    await user.logout()
    print("Logout successful")
}
```

## Example: Device Binding Callback

### Legacy

```swift
if let deviceBindingCallback = callback as? DeviceBindingCallback {
    deviceBindingCallback.bind(
        deviceName: "MyDevice",
        onSuccess: {
            print("Device binding successful")
        },
        onError: { error in
            print("Device binding failed: \(error)")
        }
    )
    
    node.next { (token, node, error) in
        // Handle response
    }
}
```

### Modern

```swift
if let bindingCallback = callback as? DeviceBindingCallback {
    do {
        let result = await callback.bind { config in
                config.deviceName = "My Device"
            }
        print("Device binding successful")
    } catch {
        print("Device binding failed: \(error)")
    }
}
```

## Example: Protecting Requests (PingOne Protect)

### Legacy

```swift
// Initialize callback with completion handler
if callback.type == "PingOneProtectInitializeCallback",
   let pingOneProtectInitCallback = callback as? PingOneProtectInitializeCallback
{
    pingOneProtectInitCallback.start { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("PingOne Protect initialized successfully")
                // Continue with the node
                node.next { (token, node, error) in
                    // Handle response
                }
            case .failure(let error):
                print("PingOne Protect initialization failed: \(error.localizedDescription)")
                // Continue with the node even on error
                node.next { (token, node, error) in
                    // Handle response
                }
            }
        }
    }
    return
}

// Evaluate callback with completion handler
if callback.type == "PingOneProtectEvaluationCallback",
   let pingOneProtectEvalCallback = callback as? PingOneProtectEvaluationCallback
{
    // Check if behavioral data should be paused
    if let shouldPause = pingOneProtectEvalCallback.pauseBehavioralData, shouldPause {
        PIProtect.pauseBehavioralData()
    }
    
    pingOneProtectEvalCallback.getData { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("PingOne Protect evaluation successful")
                // Continue with the node
                node.next { (token, node, error) in
                    // Handle response
                }
            case .failure(let error):
                print("PingOne Protect evaluation failed: \(error.localizedDescription)")
                // Continue with the node even on error
                node.next { (token, node, error) in
                    // Handle response
                }
            }
        }
    }
    return
}
```

### Modern

```swift
import PingProtect

// Initialize callback (async/await)
if let protectInitCallback = callback as? PingOneProtectInitializeCallback {
    // start() does not throw errors
    await protectInitCallback.start()
    print("PingOne Protect initialized successfully")
}

// Evaluate callback (async/await)
if let protectEvalCallback = callback as? PingOneProtectEvaluationCallback {
    // collect() does not throw errors (not getData)
    await protectEvalCallback.collect()
    print("PingOne Protect evaluation completed")
}
```

## Example: Social Login (Google)

### Legacy

```swift
import FRGoogleSignIn

// First callback: SelectIdPCallback
if let selectIdPCallback = callback as? SelectIdPCallback {
    let providersArray = selectIdPCallback.providers
    // Display providers to user and get selection
    // For this example, assume user selected Google
    let googleProvider = providersArray.first { $0.provider == "google" }
    selectIdPCallback.setProvider(provider: googleProvider!)
    
    node.next { (user: FRUser?, node, error) in
        // Handle next node with IdPCallback
    }
}

// Second callback: IdPCallback
if let idpCallback = callback as? IdPCallback {
    // SDK automatically detects Google provider from IdPClient
    // Or manually specify handler
    let handler = GoogleSignInHandler()
    
    idpCallback.signIn(handler: handler, presentingViewController: self) {
        (token: String?, tokenType: String?, error: Error?) in
        if let error = error {
            print("Google sign-in failed: \(error)")
        } else {
            print("Google sign-in successful")
        }
        
        // Social login flow completed, continue with node
        node.next { (user: FRUser?, node, error) in
            // Handle response
        }
    }
}
```

### Modern

```swift
import PingJourney
import PingExternalIdP
import PingExternalIdPGoogle

// First callback: SelectIdpCallback
if let selectIdpCallback = callback as? SelectIdpCallback {
    // Display providers to user and get selection
    let providers = selectIdpCallback.providers
    // User selects Google
    let googleProvider = providers.first { $0.provider == "google" }
    selectIdpCallback.value = googleProvider!.provider
    
    // Submit and continue to next node
    let nextNode = await node.next()
    // Handle next node with IdpCallback
}

// Second callback: IdpCallback
if let idpCallback = callback as? IdpCallback {
    let result = await idpCallback.authorize()
    
    switch result {
    case .success:
        print("Google sign-in successful")
        // Continue with the flow
        let nextNode = await node.next()
    case .failure(let error):
        print("Google sign-in failed: \(error)")
    }
}
```

## Example: Social Login (Facebook)

### Legacy

```swift
import FRFacebookSignIn

// First callback: SelectIdPCallback
if let selectIdPCallback = callback as? SelectIdPCallback {
    let providersArray = selectIdPCallback.providers
    // Display providers to user and get selection
    // For this example, assume user selected Facebook
    let facebookProvider = providersArray.first { $0.provider == "facebook" }
    selectIdPCallback.setProvider(provider: facebookProvider!)
    
    node.next { (user: FRUser?, node, error) in
        // Handle next node with IdPCallback
    }
}

// Second callback: IdPCallback
if let idpCallback = callback as? IdPCallback {
    // SDK automatically detects Facebook provider from IdPClient
    // Or manually specify handler
    let handler = FacebookSignInHandler()
    
    idpCallback.signIn(handler: handler, presentingViewController: self) {
        (token: String?, tokenType: String?, error: Error?) in
        if let error = error {
            print("Facebook sign-in failed: \(error)")
        } else {
            print("Facebook sign-in successful")
        }
        
        // Social login flow completed, continue with node
        node.next { (user: FRUser?, node, error) in
            // Handle response
        }
    }
}
```

### Modern

```swift
import PingJourney
import PingExternalIdP
import PingExternalIdPFacebook

// First callback: SelectIdpCallback
if let selectIdpCallback = callback as? SelectIdpCallback {
    // Display providers to user and get selection
    let providers = selectIdpCallback.providers
    // User selects Facebook
    let facebookProvider = providers.first { $0.provider == "facebook" }
    selectIdpCallback.value = facebookProvider!.provider
    
    // Submit and continue to next node
    let nextNode = await node.next()
    // Handle next node with IdpCallback
}

// Second callback: IdpCallback
if let idpCallback = callback as? IdpCallback {
    let result = await idpCallback.authorize()
    
    switch result {
    case .success:
        print("Facebook sign-in successful")
        // Continue with the flow
        let nextNode = await node.next()
    case .failure(let error):
        print("Facebook sign-in failed: \(error)")
    }
}
```

## Example: Social Login (Apple)

### Legacy

```swift
import AuthenticationServices

// First callback: SelectIdPCallback
if let selectIdPCallback = callback as? SelectIdPCallback {
    let providersArray = selectIdPCallback.providers
    // Display providers to user and get selection
    // For this example, assume user selected Apple
    let appleProvider = providersArray.first { $0.provider == "apple" }
    selectIdPCallback.setProvider(provider: appleProvider!)
    
    node.next { (user: FRUser?, node, error) in
        // Handle next node with IdPCallback
    }
}

// Second callback: IdPCallback
if let idpCallback = callback as? IdPCallback {
    // SDK automatically detects Apple provider from IdPClient
    // Or manually specify handler
    let handler = AppleSignInHandler()
    
    idpCallback.signIn(handler: handler, presentingViewController: self) {
        (token: String?, tokenType: String?, error: Error?) in
        if let error = error {
            print("Apple sign-in failed: \(error)")
        } else {
            print("Apple sign-in successful")
        }
        
        // Social login flow completed, continue with node
        node.next { (user: FRUser?, node, error) in
            // Handle response
        }
    }
}
```

### Modern

```swift
import PingJourney
import PingExternalIdP
import PingExternalIdPApple

// First callback: SelectIdpCallback
if let selectIdpCallback = callback as? SelectIdpCallback {
    // Display providers to user and get selection
    let providers = selectIdpCallback.providers
    // User selects Apple
    let appleProvider = providers.first { $0.provider == "apple" }
    selectIdpCallback.value = appleProvider!.provider
    
    // Submit and continue to next node
    let nextNode = await node.next()
    // Handle next node with IdpCallback
}

// Second callback: IdpCallback
if let idpCallback = callback as? IdpCallback {
    let result = await idpCallback.authorize()
    
    switch result {
    case .success:
        print("Apple sign-in successful")
        // Continue with the flow
        let nextNode = await node.next()
    case .failure(let error):
        print("Apple sign-in failed: \(error)")
    }
}
```

## Example: ReCAPTCHA Enterprise

### Legacy

```swift
import FRCaptchaEnterprise

if let recaptchaCallback = callback as? ReCaptchaEnterpriseCallback {
    // Optional payload values for customization
    recaptchaCallback.setPayload([
        "firewallPolicyEvaluation": false
    ])
    
    // Optional custom error code
    recaptchaCallback.setClientError("custom_client_error")
    
    if #available(iOS 13.0, *) {
        Task {
            do {
                try await recaptchaCallback.execute(action: "login")
                print("reCAPTCHA successful")
                // Continue with the node
                node.next { (token, node, error) in
                    // Handle response
                }
            } catch let error as RecaptchaError {
                print("reCAPTCHA failed: \(error)")
                // Handle error and continue with node
                node.next { (token, node, error) in
                    // Handle response
                }
            }
        }
    }
}
```

### Modern

```swift
import PingReCaptchaEnterprise

if let recaptchaCallback = callback as? ReCaptchaEnterpriseCallback {
    // Use verify() with optional configuration closure
    let result = await recaptchaCallback.verify { config in
        // Optionally customize payload
        config.payload = ["custom_key": "custom_value"]
    }
    
    switch result {
    case .success:
        print("reCAPTCHA successful")
    case .failure(let error):
        print("reCAPTCHA failed: \(error)")
    }
}
```

## Example: Resume Authentication Flow (Suspended Email Node)

### Legacy

```swift
// In AppDelegate or SceneDelegate
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {
    let resumeURL = url // URL contains 'suspendedId' parameter
    
    // With given resumeURI, use FRSession to resume authentication flow
    FRSession.authenticate(resumeURI: resumeURL) { (token: Token?, node, error) in
        // Handle Node, or the result of continuing the authentication flow
        if let token = token {
            print("Authentication successful")
        } else if let node = node {
            self.handleNode(node)
        } else if let error = error {
            print("Error: \(error)")
        }
    }
    
    return true
}
```

### Modern

```swift
// In AppDelegate or SceneDelegate
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {
    let resumeURL = url // URL contains 'suspendedId' parameter
    
    Task {
        // Extract suspendedId from URL and resume flow
        let node = await journey.resume(uri: resumeURL)
        
        switch node {
        case let continueNode as ContinueNode:
            handleCallbacks(continueNode)
        case let successNode as SuccessNode:
            print("Authentication successful")
        case let failureNode as FailureNode:
            print("Authentication failed")
        case let errorNode as ErrorNode:
            print("Authentication failed")
        default:
            break
        }
    }
    
    return true
}
```

## Example: Checking Current User Session

### Legacy

```swift
if let currentUser = FRUser.currentUser {
    print("User is authenticated")
    if let token = currentUser.token {
        print("Has access token: \(token.value)")
    }
} else {
    print("No authenticated user")
}
```

### Modern

```swift
if let user = await journey.journeyUser() {
    print("User is authenticated")
    
    let result = await user.token()
    switch result {
    case .success(let token):
        print("Has access token: \(token.value)")
    case .failure(let error):
        print("Error retrieving token: \(error)")
    }
} else {
    print("No authenticated user")
}
```

## Example: Getting Access Token After Session

### Legacy

```swift
// After successful session authentication, get OAuth2 tokens
if let token = token {
    print("User has session token")
    FRUser.currentUser?.getAccessToken { (user, error) in
        if let error = error {
            print("Unable to get AccessToken: \(error.localizedDescription)")
        } else if let user = user {
            print("Access token obtained: \(user.token?.value ?? "N/A")")
        }
    }
}
```

### Modern

```swift
// After successful authentication, tokens are automatically managed
if let successNode = node as? SuccessNode {
    print("User authenticated")
    if let user = await journey.journeyUser() {
        let result = await user.token()
        switch result {
        case .success(let token):
            print("Access token: \(token.value)")
        case .failure(let error):
            print("Error retrieving token: \(error)")
        }
    }
}
```

## Example: Request Interceptors

### Legacy

```swift
import FRAuth

class ForceAuthInterceptor: RequestInterceptor {
    func intercept(request: Request, action: Action) -> Request {
        if (action.type == "START_AUTHENTICATE" || action.type == "AUTHENTICATE"),
           let payload = action.payload,
           let treeName = payload["tree"] as? String,
           treeName == "BiometricsRegistration",
           let sessionToken = FRSession.currentSession?.sessionToken?.value
        {
            var headers = request.headers
            headers["Cookie"] = "\(cookieName)=\(sessionToken)"
            var urlParams = request.urlParams
            urlParams["ForceAuth"] = "true"
            
            let newRequest = Request(
                url: request.url,
                method: request.method,
                headers: headers,
                bodyParams: request.bodyParams,
                urlParams: urlParams,
                requestType: request.requestType,
                responseType: request.responseType,
                timeoutInterval: request.timeoutInterval
            )
            return newRequest
        }
        return request
    }
}

// Register interceptor
FRRequestInterceptorRegistry.shared.registerInterceptors(
    interceptors: [ForceAuthInterceptor()]
)
```

### Modern

```swift
import PingOrchestrate

// Option 1: Use built-in options when starting a journey
let node = await journey.start("BiometricsRegistration") { options in
    options.forceAuth = true
    options.noSession = false
}

// Option 2: Create a simple module for custom request modification

let customModule = Module.of { setup in
    // Intercept start requests and add custom parameters
    setup.start { context, request in
        request.setParameter(name: "ForceAuth", value: "True")
        return request
    }
    
    // Or intercept all requests in the flow
    setup.next { context, _, request in
        request.setHeader(name: "X-Custom-Header", value: "custom-value")
        return request
    }
}

// Register module during Journey configuration
let journey = Journey.createJourney { config in
    config.logger = LogManager.standard
    config.serverUrl = "https://openam.example.com/am"
    
    config.module(customModule)
}
```

## Key Differences Summary

### Architecture Changes

1. **Async/Await**: Modern SDK uses Swift's async/await instead of callbacks
2. **Workflow-Based**: New SDK uses a Workflow orchestration pattern (Journey/DaVinci as type aliases)
3. **Modular Design**: Clearer separation between core, plugins, and feature modules
4. **Type Safety**: Stronger type system with Result types and error handling

### Naming Changes

| Legacy | Modern |
|--------|--------|
| `FRAuth` | `Journey` / `DaVinci` |
| `FRUser` | `User` (from `journey.journeyUser()`) |
| `FRSession` | Session management built into Journey |
| `Node` (callback completion) | `ContinueNode` / `SuccessNode` / `FailureNode` / `ErrorNode` |
| `WebAuthnRegistrationCallback` | `FidoRegistrationCallback` |
| `WebAuthnAuthenticationCallback` | `FidoAuthenticationCallback` |
| `DeviceBindingCallback` | `DeviceBindingCallback` (same name, different module) |
| `SelectIdPCallback` | `SelectIdpCallback` |

### Module Mapping

| Legacy Module | Modern Module(s) |
|---------------|------------------|
| `FRCore` | `PingLogger`, `PingStorage`, `PingNetwork`, `PingCommons` |
| `FRAuth` | `PingOrchestrate`, `PingJourney`, `PingOidc` |
| `FRDeviceBinding` | `PingBinding` |
| `FRProximity` | `PingDeviceProfile` |
| `FRAuthenticator` | `PingOath`, `PingPush` |
| `FRGoogleSignIn` | `PingExternalIdPGoogle` |
| `FRFacebookSignIn` | `PingExternalIdPFacebook` |
| `PingProtect` | `PingProtect` (same module name) |
| `FRCaptchaEnterprise` | `PingReCaptchaEnterprise` |
| N/A (new) | `PingExternalIdPApple`, `PingFido`, `PingDeviceClient`, `PingDeviceId` |

### Callback Property Changes

The Modern SDK uses specific properties for each callback type instead of generic `setValue()` / `value` methods:

| Callback Type | Legacy | Modern |
|---------------|--------|--------|
| `NameCallback` | `callback.setValue("username")` | `callback.name = "username"` |
| `PasswordCallback` | `callback.setValue("password")` | `callback.password = "password"` |
| `ChoiceCallback` | `callback.setValue(index)` | `callback.selectedIndex = index` |
| `FidoRegistrationCallback` | `callback.register(...) { onSuccess:onError: }` | `await callback.register(...)` returns `Result` |
| `FidoAuthenticationCallback` | `callback.authenticate(...) { onSuccess:onError: }` | `await callback.authenticate(...)` returns `Result` |

**Important**: Always use the specific property name for each callback type. The generic `value` property is no longer the standard approach in the Modern SDK.

### Node State Properties

| Node Type | Property | Type | Description |
|-----------|----------|------|-------------|
| `SuccessNode` | N/A | - | Authentication succeeded |
| `ContinueNode` | `callbacks` | `[Callback]` | Array of callbacks to process |
| `FailureNode` | `cause` | `String` | Failure cause (did not exist in Legacy SDK) |
| `ErrorNode` | `message` | `String` | Error message (did not exist in Legacy SDK) |
