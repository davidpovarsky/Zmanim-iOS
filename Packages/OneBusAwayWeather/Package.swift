// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneBusAwayWeather",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OneBusAwayWeatherCore",
            targets: ["OneBusAwayWeatherCore"]
        ),
        .library(
            name: "OneBusAwayWeatherUI",
            targets: ["OneBusAwayWeatherUI"]
        ),
    ],
    targets: [
        .target(
            name: "OneBusAwayWeatherCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "OneBusAwayWeatherUI",
            dependencies: [
                "OneBusAwayWeatherCore"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OneBusAwayWeatherTests",
            dependencies: [
                "OneBusAwayWeatherCore",
                "OneBusAwayWeatherUI"
            ]
        )
    ]
)
