// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NestoryKit",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [
        // 순수 도메인(UI·저장소 비의존): 계산 엔진, 열거형, 한국어 표기
        .library(name: "NestoryKit", targets: ["NestoryKit"]),
        // SwiftData 스키마(CloudKit 호환 규칙 준수)
        .library(name: "NestoryData", targets: ["NestoryData"]),
    ],
    targets: [
        .target(
            name: "NestoryKit",
            // 제도·일정 규칙 JSON. 숫자는 코드에 넣지 않고 여기에만 둔다.
            resources: [.copy("Resources/rules")]
        ),
        .target(name: "NestoryData", dependencies: ["NestoryKit"]),
        .testTarget(name: "NestoryKitTests", dependencies: ["NestoryKit"]),
        .testTarget(name: "NestoryDataTests", dependencies: ["NestoryData", "NestoryKit"]),
    ]
)
