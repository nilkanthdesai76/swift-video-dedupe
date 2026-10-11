// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftVideoDedupe",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "VideoHashKit",
            targets: ["VideoHashKit"]
        ),
        .executable(
            name: "VideoDedupeCLI",
            targets: ["VideoDedupeCLI"]
        ),
        .executable(
            name: "VideoDedupeApp",
            targets: ["VideoDedupeApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VideoHashKit",
            dependencies: [],
            path: "Sources/VideoHashKit"
        ),
        .executableTarget(
            name: "VideoDedupeCLI",
            dependencies: ["VideoHashKit"],
            path: "Sources/VideoDedupeCLI"
        ),
        .executableTarget(
            name: "VideoDedupeApp",
            dependencies: ["VideoHashKit"],
            path: "Sources/VideoDedupeApp"
        ),
        .testTarget(
            name: "VideoHashKitTests",
            dependencies: ["VideoHashKit"],
            path: "Tests/VideoHashKitTests"
        ),
    ]
)
