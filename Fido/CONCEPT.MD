
[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# FIDO Module Design Concept

This document explains the internal design and architecture of the FIDO module, focusing on how it integrates with the `AuthenticationServices` framework and the two main Ping Identity authentication flows: DaVinci and Journey.

## Overview

The FIDO module serves as a bridge between Ping Identity's authentication flows and Apple's native FIDO capabilities through the `AuthenticationServices` framework. It provides a high-level API for FIDO registration and authentication, abstracting the complexity of the underlying credential management system.

## Architecture Components

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

    subgraph "FIDO Core"
      PingFido[Fido Instance]
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

### 1. Abstraction and Encapsulation

The `Fido` class encapsulates the interaction with the `AuthenticationServices` framework, providing a simple and clean API for FIDO operations.

### 2. Separation of Concerns

The module is divided into three main parts:
- **Core:** The `Fido` class that handles the FIDO operations.
- **DaVinci:** The collectors that integrate FIDO operations with the DaVinci flow.
- **Journey:** The callbacks that integrate FIDO operations with the Journey flow.

### 3. Testability

Dependency injection is used to allow for easy mocking of the `Fido` class, making the collectors and callbacks highly testable.

## Data Flow

### FIDO Registration Flow (DaVinci)

```mermaid
sequenceDiagram
  participant App as Mobile App
  participant Collector as FidoRegistrationCollector
  participant Server as DaVinci Server
  participant Fido as Fido Instance
  participant AuthServices as AuthenticationServices

  App ->> Server: Start Registration Flow
  Server ->> App: JSON with FIDO options
  App ->> Collector: new FidoRegistrationCollector(json)
  App ->> Collector: register()
  Collector ->> Fido: register(options)
  Fido ->> AuthServices: createCredentialRegistrationRequest(...)
  Note over AuthServices: User interaction (e.g., biometrics)
  AuthServices ->> Fido: ASAuthorizationPlatformPublicKeyCredentialRegistration
  Fido ->> Collector: Result.success(response)
  Collector ->> App: completion(success)
  App ->> Server: Send attestationValue
```

### FIDO Authentication Flow (Journey)

```mermaid
sequenceDiagram
  participant App as Mobile App
  participant Callback as FidoAuthenticationCallback
  participant Server as Journey Server
  participant Fido as Fido Instance
  participant AuthServices as AuthenticationServices

  App ->> Server: Start Authentication Flow
  Server ->> App: JSON with FIDO options
  App ->> Callback: new FidoAuthenticationCallback(json)
  App ->> Callback: authenticate()
  Callback ->> Fido: authenticate(options)
  Fido ->> AuthServices: createCredentialAssertionRequest(...)
  Note over AuthServices: User interaction (e.g., biometrics)
  AuthServices ->> Fido: ASAuthorizationPlatformPublicKeyCredentialAssertion
  Fido ->> Callback: Result.success(response)
  Callback ->> App: completion(success)
  App ->> Server: Send assertionValue
```

## Key Components Explained

### Core (`Fido.swift`)

- **Purpose**: Central coordinator for all FIDO operations.
- **Responsibilities**:
    - Manage the `AuthenticationServices` lifecycle.
    - Handle errors and exceptions consistently.
    - Provides a simple API for `register` and `authenticate`.

### DaVinci Integration (`Fido/Fido/Davinci`)

- **Purpose**: Integrates FIDO operations with the DaVinci orchestration engine.
- **Key Classes**:
    - `AbstractFidoCollector`: A factory class that creates the appropriate collector based on the `action` parameter from the server.
    - `FidoRegistrationCollector`: Handles the FIDO registration ceremony in a DaVinci flow.
    - `FidoAuthenticationCollector`: Handles the FIDO authentication ceremony in a DaVinci flow.

### Journey Integration (`Fido/Fido/Journey`)

- **Purpose**: Integrates FIDO operations with the Journey framework.
- **Key Classes**:
    - `FidoCallback`: Base class for FIDO callbacks, providing common functionality for error handling and value setting.
    - `FidoRegistrationCallback`: Handles FIDO registration in a Journey flow.
    - `FidoAuthenticationCallback`: Handles FIDO authentication in a Journey flow.
    - `CallbackInitializer`: Registers the FIDO callbacks with the Journey `CallbackRegistry`.
