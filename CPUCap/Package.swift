// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CPUCap",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CPUCap",
            path: "CPUCap",
            exclude: ["Resources/Info.plist", "Resources/CPUCap.entitlements"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
