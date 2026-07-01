// swift-tools-version: 6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "Subtitles",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "SubtitleCore",
            targets: ["SubtitleCore"]
        ),
        .executable(
            name: "SubtitlesApp",
            targets: ["SubtitlesApp"]
        ),
        .executable(
            name: "SubtitleHarness",
            targets: ["SubtitleHarness"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Sparkle",
            path: "Vendor/Sparkle/Sparkle.xcframework"
        ),
        .target(
            name: "SubtitleCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SubtitlesAppSupport",
            dependencies: ["SubtitleCore"],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .linkedFramework("MediaAccessibility")
            ]
        ),
        .executableTarget(
            name: "SubtitlesApp",
            dependencies: [
                "SubtitleCore",
                "SubtitlesAppSupport",
                "Sparkle"
            ],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .executableTarget(
            name: "SubtitleHarness",
            dependencies: ["SubtitleCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SubtitleCoreTests",
            dependencies: ["SubtitleCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SubtitlesAppSupportTests",
            dependencies: ["SubtitlesAppSupport"],
            swiftSettings: swiftSettings
        )
    ]
)
