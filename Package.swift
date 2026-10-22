// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scribe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Scribe", path: "Sources/Scribe")
    ]
)
