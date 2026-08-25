// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Drift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Drift", targets: ["Drift"])
    ],
    targets: [
        .executableTarget(
            name: "Drift",
            path: "Sources",
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/Images")
            ]
        )
    ]
)
