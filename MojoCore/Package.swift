// swift-tools-version:5.9
// MojoCore: sorting rules, scanning, planning and FileEngine. No UI, no network.
import PackageDescription

let package = Package(
    name: "MojoCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MojoCore", targets: ["MojoCore"])
    ],
    targets: [
        .target(name: "MojoCore"),
        .testTarget(name: "MojoCoreTests", dependencies: ["MojoCore"])
    ]
)
