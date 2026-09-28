// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cappucino",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Cappucino",
            path: "Sources/Cappucino"
        )
    ]
)
