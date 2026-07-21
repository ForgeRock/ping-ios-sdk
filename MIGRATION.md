[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# Migrating from the ForgeRock SDK to the Ping Orchestration SDK for iOS

This guide helps you transition from the legacy ForgeRock iOS SDK to the modern Ping Orchestration SDK for iOS.
It covers authentication flow migration as well as MFA data migration tools.

For the full official migration documentation, visit:
**[Ping SDK Migration Guide](https://developer.pingidentity.com/orchsdks/journey/migration.html)**.

## Journey Migration

The Journey module includes a comprehensive migration reference that maps every legacy ForgeRock API
to its Ping Orchestration SDK equivalent, including:

- **SDK initialization** — `FROptions` → `JourneyConfig`
- **Authentication flow** — callback-based `NodeListener` → async/await sealed `Node` types
- **Session & token management** — `FRSession` / `FRUser` → `Journey` / `User`
- **Data model translation** — complete class-by-class mapping table

See the full reference with side-by-side code examples:\
**[Journey/migration.md](./Journey/migration.md)**


## MFA Data Migration

If your app uses the legacy ForgeRock MFA capabilities (device binding, TOTP/HOTP, or push
authentication), the Ping Orchestration SDK provides dedicated migration modules that automatically transfer
existing credentials to the new storage format.

### Device Binding Migration

The `PingBinding` module includes built-in migration from the legacy `FRDeviceBinding` SDK. It
automatically migrates existing user keys and cryptographic material to the new storage format.

For setup instructions, configuration options, and troubleshooting:\
**[Binding/README.md](./Binding/README.md)**

### Authenticator (OATH & Push) Migration

The `PingAuthMigration` module migrates legacy `FRAuthenticator` TOTP, HOTP, and Push credentials
to the new `PingOath` and `PingPush` storage format.

For setup instructions, configuration options, and troubleshooting:\
**[AuthMigration/README.md](./AuthMigration/README.md)**


## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All rights reserved.
