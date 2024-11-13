// swift-tools-version:5.3
import PackageDescription

let package = Package (
    name: "PingOne-ios-sdk",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Orchestrate", targets: ["Orchestrate"]),
        .library(name: "Oidc", targets: ["Oidc"]),
        .library(name: "Davinci", targets: ["Davinci"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "Logger", dependencies: [], path: "Logger/Logger", exclude: ["Logger.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "Storage", dependencies: [], path: "Storage/Storage", exclude: ["Storage.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "Orchestrate", dependencies: [.target(name: "Logger"), .target(name: "Storage")], path: "Orchestrate/Orchestrate", exclude: ["Orchestrate.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "Oidc", dependencies: [.target(name: "Orchestrate")], path: "Oidc/Oidc", exclude: ["Oidc.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "Davinci", dependencies: [.target(name: "Oidc"),], path: "Davinci/Davinci", exclude: ["Davinci.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
    ]
)
