// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NestoryUI",
    defaultLocalization: "ko",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [
        .library(name: "NestoryUI", targets: ["NestoryUI"]),
    ],
    dependencies: [
        .package(path: "../NestoryKit"),
    ],
    targets: [
        .target(
            name: "NestoryUI",
            dependencies: [.product(name: "NestoryKit", package: "NestoryKit")],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "NestoryUITests", dependencies: ["NestoryUI"]),
    ]
)
