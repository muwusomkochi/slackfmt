// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Slackfmt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Slackfmt", targets: ["Slackfmt"]),
        .executable(name: "slackfmt-accept", targets: ["Acceptance"]),
    ],
    targets: [
        .target(name: "SlackfmtKit"),
        .executableTarget(name: "Slackfmt", dependencies: ["SlackfmtKit"]),
        .executableTarget(name: "Acceptance", dependencies: ["SlackfmtKit"]),
        .testTarget(name: "SlackfmtKitTests", dependencies: ["SlackfmtKit"]),
    ],
    swiftLanguageModes: [.v5]
)
