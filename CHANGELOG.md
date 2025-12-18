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
