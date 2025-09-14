// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Tools",
    platforms: [.macOS(.v10_11)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.57.2"),
    ],
    targets: [.target(name: "Tools", path: "")]
)
