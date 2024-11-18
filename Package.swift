// swift-tools-version:5.3
import PackageDescription

let package = Package (
    name: "Ping-SDK-iOS",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "PingLogger", targets: ["Logger"]),
        .library(name: "PingStorage", targets: ["Storage"]),
        .library(name: "PingOrchestrate", targets: ["Orchestrate"]),
        .library(name: "PingOidc", targets: ["Oidc"]),
        .library(name: "PingDavinci", targets: ["Davinci"])
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
