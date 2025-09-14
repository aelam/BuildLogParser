// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BuildLogParser",
    // Linux and Windows support are implicit in SPM
    // Only specify minimum versions for Apple platforms
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BuildLogParser",
            targets: ["BuildLogParser"]
        ),
        .executable(
            name: "buildlog-parser",
            targets: ["BuildLogParserCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BuildLogParser"
        ),
        .executableTarget(
            name: "BuildLogParserCLI",
            dependencies: [
                "BuildLogParser",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "BuildLogParserTests",
            dependencies: ["BuildLogParser"],
            resources: [
                .process("Resources")
            ]
        )
    ],
)
