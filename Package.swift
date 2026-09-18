// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rotator",
    defaultLocalization: "ko",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Rotator", targets: ["Rotator"])
    ],
    targets: [
        .target(name: "RotatorCore"),
        .target(
            name: "RotationBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "Rotator",
            dependencies: ["RotatorCore", "RotationBridge"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "RotatorCoreTests",
            dependencies: ["RotatorCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
