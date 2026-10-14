// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftUISky",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SwiftUISky", targets: ["SwiftUISky"]),
    ],
    targets: [
        .target(
            name: "SwiftUISky",
            path: "Sources/SwiftUISky"
        ),
    ]
)
