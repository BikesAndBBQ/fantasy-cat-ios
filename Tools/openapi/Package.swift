// swift-tools-version: 6.0
// A tool package, not part of the app: it exists so `make api` can run Swift
// OpenAPI Generator from the command line. The generated Swift is checked in
// under FantasyCat/API/Generated, so building the app needs no build plugin
// (and none of the "trust this plugin" prompts an agent can't click).
import PackageDescription

let package = Package(
    name: "openapi-tool",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.7.0"),
    ],
    targets: []
)
