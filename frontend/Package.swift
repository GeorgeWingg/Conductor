// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConductorFrontend",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ConductorFrontend",
            targets: ["ConductorFrontend"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ConductorFrontend",
            path: "Sources"
        )
    ]
)
