[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# ReCAPTCHA Enterprise Module - iOS

## Overview

The `PingReCaptchaEnterprise` module provides seamless integration with Google reCAPTCHA Enterprise for iOS applications using the Ping Identity SDK. This module enables advanced risk analysis to distinguish between humans and bots, protecting your applications from automated attacks, fraud, and abuse.

Google reCAPTCHA Enterprise offers enhanced detection capabilities including granular risk scores, reason codes for risky events, password breach detection, and the ability to tune site-specific models for enterprise security needs.

## Installation

### Add dependency to your project

To integrate the PingReCaptchaEnterprise module into your iOS project, add the following dependency to your `Podfile` or `Package.swift` file:

**CocoaPods**
```ruby
pod 'PingReCaptchaEnterprise', '<version>'
```

**Swift Package Manager**
```swift
.package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
```

Replace `<version>` with the latest version of the Ping iOS SDK.

### Import the Module

```swift
import PingReCaptchaEnterprise
```

## How It Works

The reCAPTCHA Enterprise integration follows this flow:

1. The SDK starts or continues an authentication journey
2. The journey encounters a reCAPTCHA Enterprise node and returns a `ReCaptchaEnterpriseCallback`
3. The client uses callback values to request a token from Google's reCAPTCHA server
4. Google returns a unique token for the transaction
5. The client adds the token to the callback and returns it to the node
6. The node submits the collected data to Google for assessment
7. Google returns the assessment, and the journey continues based on the configured score threshold

```
sequenceDiagram
    participant SDK/Client
    participant Journey
    participant ReCaptchaNode
    participant Google
    SDK/Client->>Journey: Start authentication flow
    Journey->>ReCaptchaNode: Process journey
    ReCaptchaNode->>SDK/Client: ReCaptchaEnterpriseCallback
    SDK/Client->>Google: Request reCAPTCHA token
    Google->>SDK/Client: Return token
    SDK/Client->>SDK/Client: verify() with token
    SDK/Client->>ReCaptchaNode: Submit token
    ReCaptchaNode->>Google: Assess risk
    Google->>ReCaptchaNode: Assessment result
    ReCaptchaNode->>Journey: Continue (true/false)
    Journey->>SDK/Client: Next node
```

## Usage

`ReCaptchaEnterpriseConfig` allows the developer to customize how `ReCaptchaEnterpriseCallback` is executed. If no config is provided, the callback will use the default values as shown below:

```swift
/// Configuration object for customizing reCAPTCHA Enterprise execution.
///
/// This class allows fine-grained control over reCAPTCHA behavior
/// including action names, timeouts, and provider customization.
public final class ReCaptchaEnterpriseConfig: @unchecked Sendable {

    /// The action name to associate with this reCAPTCHA execution.
    /// Different actions can be used for different user flows (login, signup, etc.)
    /// Default value is "login"
    public var action: String = ReCaptchaEnterpriseConstants.defaultAction

    /// Timeout for reCAPTCHA execution in milliseconds.
    /// Default value is 15000 (15 seconds)
    public var timeout: Double = ReCaptchaEnterpriseConstants.defaultTimeout

    /// Logger instance for recording reCAPTCHA events
    public var logger: Logger = LogManager.warning

    /// Sets additional payload value for the reCAPTCHA in callback response.
    /// Dictionary value of additional data
    public var payload: [String: Any]? = nil

    /// Initializes a new instance of `ReCaptchaEnterpriseConfig`
    public init() {}
}
```

### Basic Implementation

```swift
import PingJourney
import PingReCaptchaEnterprise

// Process Journey callbacks
node.callbacks.forEach { callback in
    switch callback {
    case let recaptchaCallback as ReCaptchaEnterpriseCallback:
        Task {

            // Execute reCAPTCHA assessment
            let result = await recaptchaCallback.verify { config in
                // Optionally customize the configuration
                config.action = "login"
                config.timeout = 20000
                config.logger = LogManager.error
            }
            switch result {
            case .success:
                // reCAPTCHA assessment successful
                // The token has been automatically set in the callback
                // Continue to the next step in the Journey
                let nextNode = await node.next()
            case .failure(let error):
                // Handle reCAPTCHA-specific errors
                print("reCAPTCHA error: \(error.errorCode) - \(error.errorMessage)")

                // Optionally set a custom error code
                recaptchaCallback.setClientError("recaptcha_failed")
            }
        }

    // Handle other callback types
    default:
        break
    }
}
```

## Advanced Configuration

### Customizing the Assessment Payload

You can add custom data to enhance the reCAPTCHA assessment. This allows you to leverage additional functionality provided by Google reCAPTCHA Enterprise:

```swift
import PingJourney
import PingReCaptchaEnterprise

// Process Journey callbacks
node.callbacks.forEach { callback in
    switch callback {
    case let recaptchaCallback as ReCaptchaEnterpriseCallback:
        Task {

            // Execute reCAPTCHA assessment
            let result = await recaptchaCallback.verify { config in
                // Optionally customize the configuration
                config.action = "purchase"
                config.timeout = 20000
                config.logger = LogManager.error
                config.payload = ["firewallPolicyEvaluation": true,
                    "transactionData": [
                        "transactionId": "TXN-12345",
                        "paymentMethod": "CREDIT_CARD",
                        "cardBin": "123456",
                        "cardLastFour": "1234",
                        "currencyCode": "USD",
                        "value": 99.99
                    ],
                    "userInfo": [
                        "accountId": "user-abc123",
                        "creationMs": "1609459200000"
                    ]
                ]
            }

            switch result {
            case .success:
                // reCAPTCHA assessment successful
                // The token has been automatically set in the callback
                // Continue to the next step in the Journey
                let nextNode = await node.next()
            case .failure(let error):
                // Handle reCAPTCHA-specific errors
                print("reCAPTCHA error: \(error.errorCode) - \(error.errorMessage)")

                // Optionally set a custom error code
                recaptchaCallback.setClientError("recaptcha_failed")
            }
        }

    // Handle other callback types
    default:
        break
    }
}
```

The default payload includes:

- `token`: The reCAPTCHA token (automatically populated)
- `siteKey`: Your reCAPTCHA site key (automatically populated)
- `userAgent`: Device user agent (automatically populated)
- `userIpAddress`: User's IP address (automatically populated)
- `expectedAction`: The action parameter (automatically populated)

You can override these values or add additional fields as needed. For more information about available payload fields, refer to the [Google reCAPTCHA Enterprise documentation](https://cloud.google.com/recaptcha-enterprise/docs).

### Setting Custom Error Codes

You can return custom error codes that the Journey node can use to branch the authentication flow:

```swift
let result = await recaptchaCallback.verify()
switch result {
case .success:
    // handle success
case .failure(let error):
    // Set a custom error code based on your business logic
    if userSuspicious {
        recaptchaCallback.setClientError("suspicious_user_behavior")
    } else {
        recaptchaCallback.setClientError("recaptcha_execution_failed")
    }

    // The Journey node can use this error code to determine the next step
}
```

## Prerequisites

### Google Cloud Setup

Before using this module, you need to:

1. **Create a Google Cloud Project**: Set up a project in the [Google Cloud Console](https://console.cloud.google.com)
2. **Enable reCAPTCHA Enterprise API**: Enable the API for your project
3. **Create reCAPTCHA Keys**: Generate site keys for your iOS application
4. **Configure Ping AIC**: Add your reCAPTCHA site key to the reCAPTCHA Enterprise node in your Journey

### Journey Configuration

Add the [reCAPTCHA Enterprise node](https://docs.pingidentity.com) to your authentication journey. This node:

- Returns the `ReCaptchaEnterpriseCallback` that the SDK handles
- Submits the assessment to Google reCAPTCHA Enterprise
- Evaluates the risk score against your configured threshold
- Routes the journey based on the assessment result (true/false outcome)

You can optionally enable the "Store reCAPTCHA assessment JSON" option in the node to save the assessment data in a variable named `CaptchaEnterpriseNode.ASSESSMENT_RESULT` for additional processing later in the journey.

## Additional Resources

- [Google reCAPTCHA Enterprise Documentation](https://cloud.google.com/recaptcha-enterprise/docs)
- [PingOne reCAPTCHA Enterprise Node Reference](https://docs.pingidentity.com)
