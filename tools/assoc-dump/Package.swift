// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "assoc-dump",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "assoc-dump")
    ]
)
