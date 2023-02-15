// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "BLResultsController",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "BLResultsController",
            type: .static,
            targets: ["BLResultsController"]),
    ],
    dependencies: [
        .package(name: "RealmSwift", url: "https://github.com/realm/realm-swift.git", from: "10.0.0"),
        .package(name: "BackgroundRealm", url: "https://github.com/BellAppLab/BackgroundRealm.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "BLResultsController",
            dependencies: ["RealmSwift", "BackgroundRealm"]),
        .testTarget(
            name: "Tests",
            dependencies: ["BLResultsController"]),
    ],
    swiftLanguageVersions: [.v5]
)
