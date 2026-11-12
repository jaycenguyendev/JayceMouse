// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JayceMouse",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JayceMouseCore", path: "Sources/JayceMouseCore"),
        .executableTarget(
            name: "JayceMouse",
            dependencies: ["JayceMouseCore"],
            path: "Sources/JayceMouse",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreBluetooth"),
            ]
        ),
        .executableTarget(name: "CoreSelfTest", dependencies: ["JayceMouseCore"], path: "Sources/CoreSelfTest"),
    ]
)
