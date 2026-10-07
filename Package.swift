// swift-tools-version: 6.2
import PackageDescription

// The Xcode project's settings: Swift 5 mode with approachable concurrency and member import visibility.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "Compositor",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Compositor", targets: ["Compositor"]),
        // The command-line tool that drives the running app; build-app.sh ships it in Contents/Helpers.
        .executable(name: "lamina", targets: ["lamina"]),
    ],
    dependencies: [
        // App updates. build-app.sh embeds Sparkle.framework in Contents/Frameworks.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        // Pixel loops (brushes, healing, levels, noise, lens, content fill, adjustments, dither), always
        // optimized: debug builds and tests paint at release speed.
        .target(name: "CPixels", path: "Sources/CPixels", cSettings: [.unsafeFlags(["-O3"])]),
        // The commands the running app answers (names, parameters, results), shared by the app, `lamina` and its MCP
        // server. Foundation only, nonisolated.
        .target(name: "LaminaAutomation", path: "Sources/LaminaAutomation", swiftSettings: [.swiftLanguageMode(.v6)]),
        // `lamina`: arguments, help, output and the Apple Event client, in a library so tests can drive it.
        .target(name: "LaminaCLI", dependencies: ["LaminaAutomation"], path: "Sources/LaminaCLI",
                swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(name: "lamina", dependencies: ["LaminaCLI"], path: "Sources/lamina",
                          swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "Compositor",
            dependencies: ["CPixels", "LaminaAutomation", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Compositor",
            swiftSettings: swiftSettings + [.defaultIsolation(MainActor.self)],
            // The app bundle keeps Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        // Runs AppKit's event loop with a document window in the test process, as the app did when it hosted the tests.
        .target(name: "CompositorTestHost", path: "Tests/CompositorTestHost", linkerSettings: [.linkedFramework("AppKit")]),
        .testTarget(name: "CompositorTests", dependencies: ["Compositor", "CompositorTestHost", "LaminaAutomation"],
                    path: "Tests/CompositorTests", swiftSettings: swiftSettings),
        // `lamina` and the command catalog, without the app: fast, no windows.
        .testTarget(name: "LaminaTests", dependencies: ["LaminaAutomation", "LaminaCLI"], path: "Tests/LaminaTests",
                    swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
