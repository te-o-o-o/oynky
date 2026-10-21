// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "oynky",
    platforms: [.macOS(.v14)],
    targets: [
        // Sampling and ranking, no UI: the menu bar app will be a thin shell over it.
        .target(name: "OynkyCore"),
        .executableTarget(name: "oynky", dependencies: ["OynkyCore"]),
        // Fixtures are read from disk through #filePath, not shipped as a bundle resource.
        .testTarget(name: "OynkyCoreTests", dependencies: ["OynkyCore"], exclude: ["Fixtures"]),
    ]
)
