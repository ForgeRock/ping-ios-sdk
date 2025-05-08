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
        .library(name: "PingExternal-idp", targets: ["PingExternal-idp"]),
        .library(name: "PingExternal-idp-Apple", targets: ["PingExternal-idp-Apple"]),
        .library(name: "PingExternal-idp-Google", targets: ["PingExternal-idp-Google"]),
        .library(name: "PingExternal-idp-Facebook", targets: ["PingExternal-idp-Facebook"])
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
        .target(name: "PingExternal-idp", dependencies: [.target(name: "PingDavinci"), .target(name: "PingBrowser")], path: "External-idp/External-idp", exclude: ["Extrernal_idp.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingExternal-idp-Apple", dependencies: [.target(name: "PingExternal-idp")], path: "External-idp-Apple/External-idp-Apple", exclude: ["Extrernal_idp_Apple.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
         .target(name: "PingExternal-idp-Google", dependencies: [.target(name: "PingExternal-idp"), .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")], path: "External-idp-Google/External-idp-Google", exclude: ["Extrernal_idp_Google.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
          .target(name: "PingExternal-idp-Facebook", dependencies: [.target(name: "PingExternal-idp"), .product(name: "FacebookLogin", package: "facebook-ios-sdk")], path: "External-idp-Facebook/External-idp-Facebook", exclude: ["Extrernal_idp_Facebook.h"], resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)
