# PingExample

A comprehensive iOS sample application demonstrating the Ping Identity iOS SDK modules (Journey orchestration, DaVinci, OIDC, MFA, push/OATH account management, device management, and developer tools).

The app's UI is built on the [PingDesignSystem](https://github.com/ForgeRock/ping-ios-design-system) Swift package — the shared Ping-branded design language (semantic tokens, view modifiers, components, and button styles) documented in that repo's [README](https://github.com/ForgeRock/ping-ios-design-system) and [DESIGN_SYSTEM.md](https://github.com/ForgeRock/ping-ios-design-system/blob/main/DESIGN_SYSTEM.md).

The project depends on the package as a remote Swift Package Manager dependency; all design-system documentation lives in the package repository, not here.

## Getting started

1. Open `PingExample.xcodeproj` (the workspace adds the SDK modules and the design-system package).
2. Configure the server values in `ConfigurationManager.swift` / the sample view models.
3. Build and run on an iOS simulator or device.
