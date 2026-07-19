// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Anagrammer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AnagramEngine"),
        .executableTarget(
            name: "Anagrammer",
            dependencies: ["AnagramEngine"],
            resources: [
                .copy("Resources/cmudict.dict"),
                .copy("Resources/enable.txt"),
            ]
        ),
        .testTarget(
            name: "AnagramEngineTests",
            dependencies: ["AnagramEngine"]
        ),
    ]
)
