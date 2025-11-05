[![Build](https://github.com/ForgeRock/unified-sdk-ios/actions/workflows/ci.yaml/badge.svg)](https://github.com/ForgeRock/unified-sdk-ios/actions/workflows/ci.yaml)

<p align="center">
  <a href="https://github.com/ForgeRock/ping-ios-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

The Ping SDK for iOS is designed for creating mobile native apps that seamlessly integrate with the PingOne platform.
It offers a range of APIs for user authentication, user device management, and accessing resources secured by PingOne.

# Modules

    ping
    ├── Browser                   # Provides in-app browser support for authentication flows.
    ├── Davinci                   # Orchestrates authentication flows with PingOne DaVinci.
    ├── Journey*                  # Orchestrates authentication flows with PingOne AIC Journeys.
    ├── ExternalIdP               # Enables authentication through various external Identity Providers (IDPs).
    ├── ExternalIdPApple          # Provides Sign in with Apple integration.
    ├── ExternalIdPFacebook       # Provides Facebook Sign-In integration. 
    ├── ExternalIdPGoogle         # Provides Google Sign-In integration.
    ├── Fido*                     # Provides FIDO2 / WebAuthn authentication support.
    ├── Logger                    # Provides a logging interface and common loggers.
    ├── MfaCommons*               # Provides common MFA capabilities such as OTP, Push, and WebAuthn.
    ├── Oath*                     # Provides OATH-based one-time password functionality.
    ├── Oidc                      # Provides OIDC login with integrated browser support.
    ├── Orchestrate               # Core authentication orchestration framework.
    ├── Protect                   # Provides advanced security integration with PingOne Protect.
    ├── Storage                   # Provides a secure storage interface.
    ├── DeviceProfile*            # Provides a framework for collecting and managing device information.
    ├── DeviceId*                 # Provides a secure method for generating and managing unique device identifiers.
    └── TamperDetector*           # Provides utilities for analyzing device integrity.

***Note***: Modules marked with an asterisk `*` are under development and considered experimental.

<!------------------------------------------------------------------------------------------------------------------------------------>
<!-- LICENSE -->

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
