# Contributing to the Ping Orchestration SDK for iOS 

Thank you for considering contributing to the Ping Orchestration SDK for iOS! We appreciate your time and effort.

This document outlines the guidelines for contributing to this project. Please read it before getting started.

## 1. Setting Up Your Development Environment

### Prerequisites

- A GitHub account with Git installed locally.
- The latest stable version of [Xcode](https://developer.apple.com/xcode/).
- iOS 16.0 or higher.
- A PingOne and Ping AIC tenants or PingAM instance

### Fork and Clone the Repository

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
    ```sh
    git clone https://github.com/YOUR_USERNAME/ping-ios-sdk.git
    cd ping-ios-sdk
    ```
3. **Open the project** in Xcode using the sample app workspace:
    ```sh
    open SampleApps/Ping.xcworkspace
    ```
4. **Verify the build** before making any changes:
    ```sh
    swift build
    ```

## 2. Project Structure

This is the Ping Orchestration SDK for iOS, a modular Swift Package Manager-based SDK that integrates with the PingAM, Ping AIC, and PingOne platforms. The SDK is organized into multiple target modules:

### Core Modules
- **PingBrowser**: Browser-based authentication flows
- **PingCommons**: Shared utilities
- **PingDavinciPlugin**: Lightweight protocol layer decoupling modules from PingDavinci
- **PingDeviceId**: Device identification utilities
- **PingDeviceProfile**: Modular device signal collection
- **PingExternalIdP**: Base external identity provider framework
- **PingJourneyPlugin**: Lightweight protocol layer decoupling modules from PingJourney
- **PingLogger**: Logging utilities (foundation module)
- **PingNetwork**: Protocol-based HTTP client with async/await
- **PingOidc**: OpenID Connect implementation
- **PingOrchestrate**: Core orchestration framework that manages workflows and modules
- **PingStorage**: Storage abstractions including Keychain, Memory, and encrypted storage

### Specialized Modules
- **PingAuthMigration**: Migrate credentials from the legacy FRAuthenticator SDK
- **PingBinding**: Device binding and signing with Secure Enclave
- **PingDavinci**: DaVinci flow handling and collector implementations
- **PingDeviceClient**: Device management REST API client for PingAM/Ping AIC
- **PingExternalIdPApple**: Apple Sign-In integration
- **PingExternalIdPGoogle**: Google Sign-In integration  
- **PingExternalIdPFacebook**: Facebook Login integration
- **PingFido**: FIDO2/WebAuthn (Passkeys) authentication
- **PingOath**: TOTP/HOTP MFA credential management
- **PingProtect**: Device protection and risk assessment
- **PingPush**: Push notification MFA
- **PingJourney**: Authentication journey management

### Module Dependencies
A number of the modules have a dependency hierarchy, as follows:
- `PingOrchestrate` depends on `PingLogger` and `PingStorage`
- `PingOidc` depends on `PingOrchestrate`
- `PingDavinci` depends on `PingOidc`
- External IdP modules depend on `PingExternalIdP`, which depends on `PingDavinci` and `PingBrowser`
- `PingProtect` depends on `PingDavinci` and external PingOneSignals SDK

For a full description of each module, see the [Modules](./README.md#modules) section in the README.

## 3. Building and Testing

Before submitting any changes, ensure the project builds and all tests pass.

### Build with Swift Package Manager

```sh
swift build
```

### Run all unit tests

```sh
xcodebuild test \
  -workspace SampleApps/Ping.xcworkspace \
  -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -enableCodeCoverage YES
```

### Run tests for a specific module

You can target individual test suites to speed up your feedback loop. Replace `<ModuleTests>` with the test target name (e.g. `DavinciTests`, `OidcTests`, `OathTests`).

```sh
xcodebuild test \
  -workspace SampleApps/Ping.xcworkspace \
  -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:<ModuleTests>
```

Some common examples:

```sh
# Core orchestration and OIDC
xcodebuild test -workspace SampleApps/Ping.xcworkspace -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:OrchestrateTests

# DaVinci
xcodebuild test -workspace SampleApps/Ping.xcworkspace -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:DavinciTests

# MFA
xcodebuild test -workspace SampleApps/Ping.xcworkspace -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:OathTests

xcodebuild test -workspace SampleApps/Ping.xcworkspace -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:PushTests
```

Ensure that all existing tests pass and that you add new tests for any new functionality you introduce.

## 4. Build API Reference Documentation

The project uses [Jazzy](https://github.com/realm/jazzy) to generate HTML API reference documentation. A convenience script is included at the root of the repository.

### Install Jazzy

```sh
[sudo] gem install jazzy
```

### Generate documentation for all modules

```sh
./generate-docs.sh
```

The generated HTML output will be placed in `docs/`.

## 5. Standards of Practice

This project follows the internal standards maintained by the Ping Identity SDK team. Please review and adhere to these guidelines before submitting any code:

- [iOS Style Guide](https://github.com/ForgeRock/sdk-standards-of-practice/blob/main/code-style/ios-styleguide.md)
- [iOS Security Guidelines](https://github.com/ForgeRock/sdk-standards-of-practice/blob/main/security/security-guidelines-ios.md)

In general, try to match the style of the existing code in the project.

## 6. Submitting a Pull Request

### 1. Create a new branch

Always branch off from `develop`. Avoid committing directly to `develop` or `main`.

```sh
git checkout -b feature/my-new-feature
```

### 2. Make and commit your changes

Write clean, readable code. Add tests for new functionality and update documentation where relevant.

Commits must be **signed**. See the [GitHub docs](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits) for setup instructions.

Use the following commit message format:

```
[TYPE] Short description of the changes
```

| Type | When to use |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation changes only |
| `refactor` | Code restructuring with no behaviour change |
| `test` | Adding or modifying tests |

Example:

```sh
git commit -S -m "feat: add TOTP token refresh support"
```

### 3. Push and open a Pull Request

```sh
git push origin feature/my-new-feature
```

Open a Pull Request targeting the `develop` branch of the original repository. Fill out the PR template, which includes:

- A clear description of **what** was changed and **why**.
- A link to the related JIRA ticket, if applicable.
- Any relevant context, screenshots, or notes about breaking changes.

Your PR will be reviewed by the project maintainers. Be prepared to address feedback and keep your branch up to date with `develop`.

## License

By contributing to the Ping Orchestration SDK for iOS, you agree that your contributions will be licensed under the [MIT License](LICENSE) that covers the project.

&copy; Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved.
