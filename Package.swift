// swift-tools-version:5.9
import PackageDescription

let package = Package (
    name: "Ping-SDK-iOS",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v16)
    ],
    products: [
        .library(name: "PingLogger", targets: ["PingLogger"]),
        .library(name: "PingStorage", targets: ["PingStorage"]),
        .library(name: "PingOrchestrate", targets: ["PingOrchestrate"]),
        .library(name: "PingOidc", targets: ["PingOidc"]),
        .library(name: "PingDavinci", targets: ["PingDavinci"]),
        .library(name: "PingDavinciPlugin", targets: ["PingDavinciPlugin"]),
        .library(name: "PingBrowser", targets: ["PingBrowser"]),
        .library(name: "PingJourney", targets: ["PingJourney"]),
        .library(name: "PingJourneyPlugin", targets: ["PingJourneyPlugin"]),
        .library(name: "PingMfaCommons", targets: ["PingMfaCommons"]),
        .library(name: "PingBinding", targets: ["PingBinding"]),
        .library(name: "PingExternalIdP", targets: ["PingExternalIdP"]),
        .library(name: "PingExternalIdPApple", targets: ["PingExternalIdPApple"]),
        .library(name: "PingExternalIdPGoogle", targets: ["PingExternalIdPGoogle"]),
        .library(name: "PingExternalIdPFacebook", targets: ["PingExternalIdPFacebook"]),
        .library(name: "PingProtect", targets: ["PingProtect"]),
        .library(name: "PingReCaptchaEnterprise", targets: ["PingReCaptchaEnterprise"]),
    ],
    dependencies: [
		.package(url: "https://github.com/pingidentity/pingone-signals-sdk-ios.git", "5.3.0" ..< "5.4.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", "16.3.1" ..< "16.4.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", "9.0.0" ..< "10.0.0"),
        .package(url: "https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk.git", "18.8.1" ..< "18.9.0"),
    ],
    targets: [
        .target(name: "PingLogger", dependencies: [], path: "Logger/Logger", exclude: ["Logger.h"]),
        .target(name: "PingStorage", dependencies: [], path: "Storage/Storage", exclude: ["Storage.h"]),
        .target(name: "PingOrchestrate", dependencies: [.target(name: "PingLogger"), .target(name: "PingStorage")], path: "Orchestrate/Orchestrate", exclude: ["Orchestrate.h"]),
        .target(name: "PingOidc", dependencies: [.target(name: "PingOrchestrate"), .target(name: "PingBrowser")], path: "Oidc/Oidc", exclude: ["Oidc.h"]),
        .target(name: "PingDavinciPlugin", dependencies: [.target(name: "PingLogger")], path: "PingDavinciPlugin/PingDavinciPlugin"),
        .target(name: "PingDavinci", dependencies: [.target(name: "PingOidc"), .target(name: "PingDavinciPlugin")], path: "Davinci/Davinci", exclude: ["Davinci.h"]),
        .target(name: "PingBrowser", dependencies: [.target(name: "PingLogger")], path: "Browser/Browser", exclude: ["Browser.h"]),
        .target(name: "PingJourneyPlugin", dependencies: [.target(name: "PingLogger")], path: "PingJourneyPlugin/PingJourneyPlugin"),
        .target(name: "PingJourney", dependencies: [.target(name: "PingOidc"), .target(name: "PingOrchestrate"), .target(name: "PingJourneyPlugin")], path: "Journey/Journey", exclude: ["Journey.h"]),
        .target(name: "PingMfaCommons", dependencies: [.target(name: "PingLogger")], path: "MfaCommons/MfaCommons", exclude: ["MfaCommons.h"]),
        .target(name: "PingBinding", dependencies: [.target(name: "PingOrchestrate"), .target(name: "PingOidc"), .target(name: "PingJourneyPlugin"), .target(name: "PingMfaCommons"), .target(name: "PingStorage"), .target(name: "PingLogger")], path: "Binding/Binding"),
        .target(name: "PingExternalIdP", dependencies: [.target(name: "PingDavinciPlugin"), .target(name: "PingBrowser")], path: "ExternalIdP/ExternalIdP", exclude: ["ExternalIdP.h"]),
        .target(name: "PingExternalIdPApple", dependencies: [.target(name: "PingExternalIdP")], path: "ExternalIdPApple/ExternalIdPApple", exclude: ["ExternalIdPApple.h"]),
        .target(name: "PingExternalIdPGoogle", dependencies: [.target(name: "PingExternalIdP"), .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")], path: "ExternalIdPGoogle/ExternalIdPGoogle", exclude: ["ExternalIdPGoogle.h"]),
    	.target(name: "PingExternalIdPFacebook", dependencies: [.target(name: "PingExternalIdP"), .product(name: "FacebookLogin", package: "facebook-ios-sdk")], path: "ExternalIdPFacebook/ExternalIdPFacebook", exclude: ["ExternalIdPFacebook.h"]),
    	.target(name: "PingProtect", dependencies: [.target(name: "PingDavinciPlugin"), .product(name: "PingOneSignals", package: "pingone-signals-sdk-ios")], path: "Protect/Protect", exclude: ["Protect.h"]),
        .target(name: "PingReCaptchaEnterprise", dependencies: [.target(name: "PingJourneyPlugin"), .target(name: "PingLogger"), .product(name: "RecaptchaEnterprise", package: "recaptcha-enterprise-mobile-sdk")], path: "ReCaptchaEnterprise/ReCaptchaEnterprise", exclude: ["ReCaptchaEnterprise.h"]),
    ]
)
