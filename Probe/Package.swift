// swift-tools-version:5.9
// T01 probe. Throwaway: answers how macOS behaves before Mojo is built.
import PackageDescription

let package = Package(
    name: "MojoProbe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MojoProbe", path: "Sources/MojoProbe")
    ]
)
