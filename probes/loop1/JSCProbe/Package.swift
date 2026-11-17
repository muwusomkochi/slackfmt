// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JSCProbe",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ProbeKit"),
        .executableTarget(name: "x2-time", dependencies: ["ProbeKit"]),
        .executableTarget(name: "x3-write", dependencies: ["ProbeKit"]),
        .executableTarget(name: "x4-decode", dependencies: ["ProbeKit"]),
        .testTarget(name: "ProbeTests", dependencies: ["ProbeKit"]),
    ]
)
