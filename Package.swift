// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Overdrive",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Overdrive",
            path: "Sources/Overdrive",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "OverdriveTests",
            dependencies: ["Overdrive"],
            path: "Tests/OverdriveTests"
        ),
    ]
)
