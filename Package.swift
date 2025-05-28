// swift-tools-version: 6.0
import PackageDescription

let package = Package (
    name: "Ping-SDK-iOS",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "PingLogger", targets: ["PingLogger"]),
        .library(name: "PingStorage", targets: ["PingStorage"]),
        .library(name: "PingOrchestrate", targets: ["PingOrchestrate"]),
        .library(name: "PingOidc", targets: ["PingOidc"]),
        .library(name: "PingDavinci", targets: ["PingDavinci"]),
        .library(name: "PingBrowser", targets: ["PingBrowser"]),
        .library(name: "PingExternalIdP", targets: ["PingExternalIdP"]),
        .library(name: "PingExternalIdPApple", targets: ["PingExternalIdPApple"]),
        .library(name: "PingExternalIdPGoogle", targets: ["PingExternalIdPGoogle"]),
        .library(name: "PingExternalIdPFacebook", targets: ["PingExternalIdPFacebook"])
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", "16.3.1" ..< "16.4.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", "8.1.0-vwg-eap-1.0.0" ..< "8.2.0"))
    ],
    targets: [
        .target(name: "PingLogger", dependencies: [], path: "Logger/Logger", exclude: ["Logger.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingStorage", dependencies: [], path: "Storage/Storage", exclude: ["Storage.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOrchestrate", dependencies: [.target(name: "PingLogger"), .target(name: "PingStorage")], path: "Orchestrate/Orchestrate", exclude: ["Orchestrate.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOidc", dependencies: [.target(name: "PingOrchestrate")], path: "Oidc/Oidc", exclude: ["Oidc.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingDavinci", dependencies: [.target(name: "PingOidc"),], path: "Davinci/Davinci", exclude: ["Davinci.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingBrowser", dependencies: [.target(name: "PingLogger"),], path: "Browser/Browser", exclude: ["Browser.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingExternalIdP", dependencies: [.target(name: "PingDavinci"), .target(name: "PingBrowser")], path: "ExternalIdP/ExternalIdP", exclude: ["ExtrernalIdP.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingExternalIdPApple", dependencies: [.target(name: "PingExternalIdP")], path: "ExternalIdPApple/ExternalIdPApple", exclude: ["ExtrernalIdPApple.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
         .target(name: "PingExternalIdPGoogle", dependencies: [.target(name: "PingExternalIdP"), .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")], path: "ExternalIdPGoogle/ExternalIdPGoogle", exclude: ["ExtrernalIdPGoogle.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
          .target(name: "PingExternalIdPFacebook", dependencies: [.target(name: "PingExternalIdP"), .product(name: "FacebookLogin", package: "facebook-ios-sdk")], path: "ExternalIdPFacebook/ExternalIdPFacebook", exclude: ["ExtrernalIdPFacebook.h"], resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)
