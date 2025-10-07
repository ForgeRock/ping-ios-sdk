
[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# FIDO2 Module Design Concept

This document explains the internal design and architecture of the FIDO2 module, focusing on how it integrates with the `AuthenticationServices` framework.

## Overview

The FIDO2 module serves as a bridge between Ping Identity's authentication flows (DaVinci and Journey) and Apple's native FIDO2 capabilities through the `AuthenticationServices` framework. The `PingFido` class acts as a proxy, abstracting the complexity of the underlying credential management system while providing a clean, consistent API for authentication operations.

## Architecture Components

### Component Diagram

```mermaid
graph TB
  subgraph "Application Layer"
    App[Mobile App]
  end

  subgraph "Ping Identity SDK"
    subgraph "DaVinci Flow"
      DVC[DaVinci Collectors]
    end

    subgraph "Journey Flow"
      JC[Journey Callbacks]
    end

    subgraph "FIDO2 Core"
      PingFido[PingFido Instance]
    end
  end

  subgraph "Platform Interface"
    AuthServices[AuthenticationServices Framework]
  end

%% Dependencies
  App --> DVC
  App --> JC
  DVC --> PingFido
  JC --> PingFido

  PingFido --> AuthServices

%% Styling
  classDef pingSDK fill:#e1f5fe
  classDef core fill:#f3e5f5
  classDef apple fill:#e8f5e8

  class DVC,JC pingSDK
  class PingFido core
  class AuthServices apple
```

## Design Principles

### 1. Proxy Pattern

The `PingFido` class acts as a proxy to the `AuthenticationServices` framework:

- **Abstraction**: Hides the complexity of the `AuthenticationServices` API.
- **Error Handling**: Provides consistent error handling and reporting.

### 2. Dependency Injection

Both DaVinci Collectors and Journey Callbacks will depend on configurable `PingFido` instances:

- **Loose Coupling**: Components depend on the abstraction, not the implementation.
- **Testability**: Easy to mock the `PingFido` instance for unit testing.
- **Consistency**: All authentication flows use the same underlying FIDO2 operations.

## Data Flow

### FIDO2 Registration Flow

```mermaid
sequenceDiagram
  participant App as Mobile App
  participant SDK as Ping SDK
  participant Server as Auth Server
  participant PingFido as PingFido Instance
  participant AuthServices as AuthenticationServices

  App ->> SDK: Start Registration Flow
  SDK ->> Server: Start Registration Flow
  Server ->> SDK: Registration Challenge (JSON)
  SDK ->> PingFido: register(options)
  PingFido ->> AuthServices: createCredentialRegistrationRequest(...)
  Note over AuthServices: User interaction:<br/>- Select authenticator<br/>- Biometric verification<br/>- Create credential
  AuthServices ->> PingFido: ASAuthorizationPlatformPublicKeyCredentialRegistration
  PingFido ->> SDK: Result<[String: Any]>
  SDK ->> App: Registration Complete
  App ->> SDK: next()
  SDK ->> Server: process node
```

### FIDO2 Authentication Flow

Similar to the registration flow, but calling `authenticate()` instead of `register()`.

## Key Components Explained

### PingFido

- **Location**: `Fido/Fido`
- **Purpose**: Central coordinator for all FIDO2 operations and Journey callbacks.
- **Responsibilities**:
    - Manage the `AuthenticationServices` lifecycle.
    - Handle errors and exceptions consistently.
    - Support both discoverable and non-discoverable credentials.
    - Provides the Journey callbacks for FIDO2 operations.
- **Key Classes**:
    - `PingFido.swift`: The main class that orchestrates the FIDO2 registration and authentication processes.
    - `FidoModels.swift`: Contains the data models for FIDO2 requests and responses.
    - `FidoConstants.swift`: Defines the constants used in the FIDO2 implementation.
    - `PingFido.h`: The header file for the module.
    - **Journey**: Contains the Journey callbacks for FIDO2 operations.
        - `Fido2Callback.swift`: Base class for FIDO2 callbacks.
        - `Fido2RegistrationCallback.swift`: Handles FIDO2 registration.
        - `Fido2AuthenticationCallback.swift`: Handles FIDO2 authentication.
        - `CallbackInitializer.swift`: Registers the FIDO2 callbacks with the Journey framework.

### DaVinci Collectors & Journey Callbacks

The integration with DaVinci is not yet implemented. The integration with Journey is handled by the `PingFido` module.

