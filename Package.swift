// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MusicViz",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "MusicViz", targets: ["MusicVizApp"]),
        .library(name: "MusicVizCore", targets: ["MusicVizCore"])
    ],
    targets: [
        .target(
            name: "MusicVizCore",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "MusicVizApp",
            dependencies: ["MusicVizCore"]
        ),
        .testTarget(
            name: "MusicVizCoreTests",
            dependencies: ["MusicVizCore"]
        )
    ]
)
