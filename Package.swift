// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FixText",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FixText",
            targets: ["FixText"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FixText",
            path: "Sources/FixTextApp"
        )
    ]
)
