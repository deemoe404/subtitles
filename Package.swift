// swift-tools-version: 6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let distributionChannel = Context.environment["ONEMORECAP_DISTRIBUTION_CHANNEL"]?.lowercased()
let isAppStoreOnlyManifest = distributionChannel == "appstore"

var products: [Product] = [
    .library(
        name: "SubtitleCore",
        targets: ["SubtitleCore"]
    )
]

if !isAppStoreOnlyManifest {
    products.append(
        .executable(
            name: "OneMoreCapApp",
            targets: ["OneMoreCapApp"]
        )
    )
}

products.append(
    .executable(
        name: "OneMoreCapAppStore",
        targets: ["OneMoreCapAppStore"]
    )
)
products.append(
    .executable(
        name: "SubtitleHarness",
        targets: ["SubtitleHarness"]
    )
)

var targets: [Target] = [
    .target(
        name: "SubtitleCore",
        swiftSettings: swiftSettings
    ),
    .target(
        name: "OneMoreCapAppSupport",
        dependencies: ["SubtitleCore"],
        swiftSettings: swiftSettings,
        linkerSettings: [
            .linkedFramework("MediaAccessibility")
        ]
    ),
    .target(
        name: "OneMoreCapAppCommon",
        dependencies: [
            "SubtitleCore",
            "OneMoreCapAppSupport"
        ],
        swiftSettings: swiftSettings
    ),
    .executableTarget(
        name: "OneMoreCapAppStore",
        dependencies: [
            "OneMoreCapAppSupport",
            "OneMoreCapAppCommon"
        ],
        swiftSettings: swiftSettings
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
    )
]

if isAppStoreOnlyManifest {
    targets.append(
        .testTarget(
            name: "OneMoreCapAppSupportTests",
            dependencies: ["OneMoreCapAppSupport"],
            exclude: ["AppleTVPlaybackTests.swift"],
            swiftSettings: swiftSettings
        )
    )
} else {
    targets.append(contentsOf: [
        .binaryTarget(
            name: "Sparkle",
            path: "Vendor/Sparkle/Sparkle.xcframework"
        ),
        .target(
            name: "OneMoreCapAppleTVSupport",
            dependencies: ["OneMoreCapAppSupport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "OneMoreCapGitHubSupport",
            dependencies: [
                "OneMoreCapAppCommon",
                "Sparkle"
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "OneMoreCapApp",
            dependencies: [
                "OneMoreCapAppSupport",
                "OneMoreCapAppleTVSupport",
                "OneMoreCapAppCommon",
                "OneMoreCapGitHubSupport"
            ],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "OneMoreCapAppSupportTests",
            dependencies: [
                "OneMoreCapAppSupport",
                "OneMoreCapAppleTVSupport"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OneMoreCapAppCommonTests",
            dependencies: [
                "OneMoreCapAppCommon",
                "OneMoreCapAppSupport",
                "OneMoreCapAppleTVSupport"
            ],
            swiftSettings: swiftSettings
        )
    ])
}

let package = Package(
    name: "OneMoreCap",
    platforms: [
        .macOS("26.0")
    ],
    products: products,
    targets: targets
)
