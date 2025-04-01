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
        .library(name: "PingExternal-idp", targets: ["PingExternal-idp"])
    ],
    dependencies: [
        .package(name: "Facebook", url: "https://github.com/facebook/facebook-ios-sdk.git", .upToNextMinor(from: "16.3.1")),
        .package(name: "GoogleSignIn", url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMinor(from: "8.1.0-vwg-eap-1.0.0"))
    ],
    targets: [
        .target(name: "PingLogger", dependencies: [], path: "Logger/Logger", exclude: ["Logger.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingStorage", dependencies: [], path: "Storage/Storage", exclude: ["Storage.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOrchestrate", dependencies: [.target(name: "PingLogger"), .target(name: "PingStorage")], path: "Orchestrate/Orchestrate", exclude: ["Orchestrate.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOidc", dependencies: [.target(name: "PingOrchestrate")], path: "Oidc/Oidc", exclude: ["Oidc.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingDavinci", dependencies: [.target(name: "PingOidc"),], path: "Davinci/Davinci", exclude: ["Davinci.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingBrowser", dependencies: [.target(name: "PingLogger"),], path: "Browser/Browser", exclude: ["Browser.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingExternal-idp", dependencies: [.target(name: "PingDavinci"), .target(name: "PingBrowser"), .product(name: "FacebookLogin", package: "Facebook"), .product(name: "GoogleSignIn", package: "GoogleSignIn")], path: "External-idp/External-idp", exclude: ["ExtrernalIdp.h"], resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)
