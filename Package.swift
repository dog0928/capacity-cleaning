// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "capacity-cleaning",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "capacity-cleaning", targets: ["CapacityCleaning"])
    ],
    targets: [
        .executableTarget(
            name: "CapacityCleaning",
            path: "Sources/CapacityCleaning"
        )
    ]
)
