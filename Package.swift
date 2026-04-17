// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SunTzuCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SunTzuCore", targets: ["SunTzuCore"]),
    ],
    targets: [
        .target(
            name: "SunTzuCore",
            path: "Sources/SunTzuCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SunTzuCoreTests",
            dependencies: ["SunTzuCore"],
            path: "Tests/SunTzuCoreTests"
        ),
    ]
)
