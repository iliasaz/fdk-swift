// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "fdk-swift",
    products: [
        .library(
            name: "fdk-swift",
            targets: ["fdk-swift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "fdk-swift",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ]),
    ]
)
