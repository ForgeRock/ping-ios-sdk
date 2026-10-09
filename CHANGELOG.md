## [UNRELEASED]

#### Changed

- Changed Recognize error reporting to the shared cross-platform error model, matching the web SDK. `RecognizeError` now carries the shared `code` and `name` (e.g. `CORE_USER_NOT_ENROLLED` / 3003), and keeps the native Keyless code in the new `sdkCode` property. The `clientError` Journey input now carries the shared error name and `clientErrorCode` the shared code; an error with no shared name is reported as `SDK_ERROR` (1000). **Upgrade note:** `RecognizeError.code` and the submitted `clientErrorCode` used to be native Keyless codes (e.g. 20000), and `clientError` used to be the error message. App or Journey logic that branches on those values must use the shared codes and names listed in the Recognize README. The native code is still available in `sdkCode`, and the message in `RecognizeError.message` [P1RECMOB-3847]

## [2.2.0]

#### Added

- Added new `PingRecognize` module for PingOne Recognize biometric authentication (enrollment and authentication) [P1RECMOB-3663]
- Added new `PingOneMFA` module wrapping the native PingOne MFA SDK (`PingOneSDK`)
- Added `MobilePairingCollector` to support pairing with PingOne [P14C-91504]
- Added `ImageCollector` to support image display in DaVinci forms [SDKS-5143]
- Added `MetadataCollector` for the DaVinci SDK Connector pause/resume model [SDKS-5142]
- Added `trigger` and `isAutomatic` to the DaVinci FIDO collectors [SDKS-4552]
- Added Facebook Limited Login support in `PingExternalIdPFacebook` [SDKS-5160, SDKS-5161, SDKS-5162]
- Added present-only launch mode to `BrowserLauncher` via `browserMode: .custom` [SDKS-5357]
- Added `OidcError.configurationError` for configurations with neither a usable `discoveryEndpoint` nor `openId` [SDKS-5301]
- Added opt-in commercial device-model-name resolution to `DeviceProfileCallback` via `PlatformCollector(includeModelName: true)`; the default `PlatformCollector()` payload is unchanged. See the `DeviceProfile` README for upgrade notes [SDKS-5275]

#### Updated

- Redesigned the PingExample sample app with a shared design system [SDKS-5054]
- Updated `facebook-ios-sdk` dependency to 18.1.0 [SDKS-5160]
- `oidc.discoveryEndpoint` in the unified JSON configuration is now optional when `oidc.openId` is supplied [SDKS-5301]

#### Fixed

- Fixed FIDO registration/authentication not launching automatically when the DaVinci form's `trigger` is not `BUTTON` [SDKS-4552]
- Fixed FIDO2 client-side WebAuthn errors (cancellation, timeout, etc.) not routing to the DaVinci error branch [SDKS-4478]
- Fixed `OidcWebClient` `.authSession` and `.ephemeralAuthSession` not completing for Universal Link (https) redirect URIs [SDKS-5239]
- Fixed `OidcWebClient.authorize()` collapsing `FailureNode.cause` to `.unknown` [SDKS-5295]
- Restored support for supplying `OidcClientConfig.openId` directly (no-discovery mode), as in 2.0.0 [SDKS-5301]
- Fixed the async `OidcClient.generateAuthorizeUrl(customParams:)` silently skipping PAR when called before `oidcInitialize()` [SDKS-5403]
- Fixed 5xx AM responses with a parseable error body being misclassified as `FailureNode` instead of `ErrorNode` [SDKS-5358]
- Fixed `Journey.start(backchannelUri:)` not rejecting whitespace-only `authIndexType`/`authIndexValue` [SDKS-5359]
- Fixed `QRCodeCollector` not preserving the complete QR code data URI in `content` [SDKS-5299]
- Fixed `swift build` (macOS) failing in `PingOidc` on non-iOS platforms [SDKS-5443]

#### Changed

- `PingJourney` no longer hard-depends on `PingDeviceProfile` — apps using the Device Profile Collector node must add `PingDeviceProfile` to their `Package.swift` or `Podfile` [SDKS-5443]
- `CallbackRegistry.callback(from:)` now logs when a callback type has no registered handler [SDKS-5443]
- A blank `oidc.discoveryEndpoint` with no `oidc.openId` now fails at parse time instead of at first use [SDKS-5301]
- `OidcError` now includes `configurationError`; exhaustive `switch` statements over `OidcError` must handle the new case [SDKS-5301]
- `OidcClientConfig.oidcInitialize()` cancellation is now isolated per caller, so cancelling one caller no longer cancels a shared discovery operation for other callers [SDKS-5301]
- `SubmitCollector`, `FlowCollector`, and `MetadataCollector` now expose `actionKey` via the new `ActionKeyProvider` protocol [SDKS-5290]

## [2.1.1]
#### Added
- Added support for Xcode 27 and iOS 27 [SDKS-5306]

#### Updated
- Updated `RecaptchaEnterprise` dependency to 18.9.1 for Xcode 27 / iOS 27 compatibility [SDKS-5306]

## [2.1.0]
#### Added
- Added OAuth 2.0 Device Authorization Grant (RFC 8628) support [SDKS-4785]
- Added Pushed Authorization Request (PAR) support for OIDC [SDKS-4235]
- Added unified JSON configuration support [SDKS-5066]
- Added `PollingCollector` for DaVinci flows [SDKS-4682]
- Added `QrCodeCollector` for DaVinci flows [SDKS-4680]
- Added `SingleCheckboxCollector` for DaVinci forms [SDKS-4920]
- Added `ReadOnlyTextCollector` for DaVinci forms [SDKS-4928]
- Added `RichContent` and `RichContentReplacement` types with rich text and embedded link support to `LabelCollector` [SDKS-4245]
- Added phone number extension support in `PhoneNumberCollector` [SDKS-4668]
- Added `PushError.pushNumberChallengeError` to surface a distinct failure for Push Number Challenge responses [SDKS-5115]
- Added `preferImmediatelyAvailableCredentials` option to FIDO authentication to restrict the ceremony to locally-available credentials only [SDKS-5212]
- Added `AuthMigration` module for migrating existing sessions from the legacy ForgeRock SDK [SDKS-4773]
- Added Page Node description, header, and footer support [SDKS-4762]
- Added AM/AIC backchannel authentication support to the `PingJourney` module via `Journey.start(backchannelUri:configure:)` [SDKS-5156]

#### Fixed
- Fixed permanent authentication failure after iCloud device migration caused by Secure Enclave key mismatch [SDKS-5172]
- Fixed `PingFido` WebAuthn registration ignoring the configured `displayName` during passkey creation [SDKS-5211]
- Fixed `PasswordCollector` not handling nested password policies [SDKS-4695]
- Fixed PIN verification during device binding registration [SDKS-5015]
- Fixed `Protect` collector being triggered multiple times within a flow [SDKS-4769]
- Fixed browser close and reset logic [SDKS-4717]
- Fixed Device Binding authenticators incorrectly reporting as supported on simulator [SDKS-4836]
- Fixed `DeviceBindingConfig` device name defaulting to the user-assigned name instead of the device model [SDKS-4850]
- Fixed `DefaultDeviceIdentifier` to reuse the legacy device identifier when available [SDKS-4630]
- Fixed Swift build failures — platform bump and `canImport` guards [SDKS-4916]
- Fixed FIDO ceremony logs not routing through the workflow logger [SDKS-4924]

## [2.0.0]
#### Added
- Added new `PingJourney` module [SDKS-3918]
- Added new `PingNetwork` module [SDKS-4496]
- Added new `PingDeviceClient` module [SDKS-4491]
- Added new `PingDeviceId` module [SDKS-4122]
- Added new `PingDeviceProfile` module [SDKS-4128]
- Added new `PingTamperDetector` module [SDKS-4366]
- Added new `PingJourneyPlugin` and `PingDavinciPlugin` modules [SDKS-4492]
- Added new `PingCommons` module [SDKS-4104]
- Added new `PingOath` module [SDKS-4100]
- Added new `PingPush` module [SDKS-4105]
- Added new `PingFido` module [SDKS-4137]
- Added new `PingBinding` module [SDKS-4117]
- Added new `PingReCaptchaEnterprise` module [SDKS-4440]
- Added support for core callbacks in the `PingJourney` module [SDKS-4060]
- Added support for native social login for Facebook, Google and Apple for AIC [SDKS-3898]
- Added migration mechanism for existing device binding data from the Legacy SDK to the new SDK [SDKS-4495]

#### Fixes
- Updated `PingStorage` module to allow multiple DaVinci/Journey instances to have separate cookies, sessions, and token storage [SDKS-4588]

## [1.3.1]
#### Fixed
- Fixed an issue in the `PingProtect` module causing a crash on iOS 17+ due to an incorrect actor executor assumption [SDKS-4494] 
- Updated all targets to use the Swift 6 compiler [SDKS-4499]

## [1.3.0]
#### Added
- New `PingProtect` module [SDKS-4071]
- Support for the `Protect` collector and integration with DaVinci [SDKS-4073]
- New `PingOidc` login module with integrated browser support [SDKS-4149]

#### Updated
- Country code format for the `PhoneNumber` collector in DaVinci [SDKS-4199]
- Redesigned and improved PingExample app [SDKS-4104]

## [1.2.0]

#### Added
- Support for native social login with Apple, Google and Facebook [SDKS-3450]
- Support for PingOne Forms MFA OTP components `DEVICE_REGISTRATION`, `DEVICE_AUTHENTICATION`, and `PHONE_NUMBER` [SDKS-3563]
- Support for accessing the previous `ContinueNode` from `ErrorNode` [SDKS-3891]
- Support for accessing the `key` attribute of `LabelCollector` [SDKS-3956]
- New `PingExternalIdPApple` module [SDKS-3958]
- New `PingExternalIdPGoogle` module [SDKS-3958]
- New `PingExternalIdPFacebook` module [SDKS-3958]

#### Fixed
- Resolved an issue where cookies were incorrectly cleared from in-memory storage on requests containing a `Set-Cookie` header [SDKS-4189]

#### Changed
- Renamed `PingExternal-idp` module to `PingExternalIdP` [SDKS-3958]

## [1.1.0]

#### Added
- Support for PingOne Forms field types LABEL, CHECKBOX, DROPDOWN, COMBOBOX, RADIO, PASSWORD, PASSWORD_VERIFY, FLOWLINK [SDKS-3671, SDKS-3672]
- Support for validation of PingOne Forms fields [SDKS-3671, SDKS-3672]
- Handling default values for PingOne Forms fields [SDKS-3674]
- Interface for access of ErrorNode with validation error [SDKS-3675]
- Support for Social Login with Browser Redirect [SDKS-3720]
- Support for `Accept-Language` header [SDKS-3623]
- Swift 6 Support [SDKS-3728]
- New `PingBrowser` module [SDKS-3920]
- New `PingExternal-idp` module [SDKS-3920]

## [1.0.0]
- General Availability release of the Ping SDK for iOS

#### Added
- Added Logger initial version
- Added Storage initial version
- Added Oidc initial version
- Added Orchestrate initial version
- Added Davinci initial version
