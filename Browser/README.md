<p align="center">
  <a href="https://github.com/ForgeRock/ping-android-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

# Ping Browser

## Overview

Ping Browser is a library that allows you to instanciate and use an in-app browser for performing OIDC flows. 
This library act as a plugin to the `External_idp` library,
and it provides the necessary configuration to launch the browser to authenticate with the External IDP.

## Add dependency to your project

You can add the dependency using Cocoapods or Swift Package manager

## Usage

The `PingBrowser` is used internally in the `External_idp` module. You can use the `PingBrowser` in standalone mode by calling the following:
```swift
await BrowserLauncher.currentBrowser?.launch(url: request.urlRequest.url!, customParams: nil, browserType: .authSession, browserMode: .login, callbackURLScheme: callbackURLScheme)
```


### BrowserLauncher configuration

The `BrowserLauncher` has the following public methods:
1. `Reset()`
2. `launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String) async throws -> URL`

The `BrowserLauncher` supports the following types of `BrowserMode` (Not fully implemented yet):
1. `login`
2. `logout`
3. `custom`

The `BrowserLauncher` supports the following types of `BrowserType` (Not fully implemented yet):
1. `authSession` <-- Default
2. `sfViewController`
3. `nativeBrowserApp`
4. `ephemeralAuthSession`

At the current time only `authSession` and `ephemeralAuthSession` are implemented. Both types rely on the `ASWebAuthenticationSession` in-app browser type.