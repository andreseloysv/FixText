// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FixTextApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FixTextApp",
            targets: ["FixTextApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FixTextApp",
            path: "Sources/FixTextApp"
        )
    ]
)
