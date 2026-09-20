// swift-tools-version: 6.0
// The app's pure logic: no UI, no network, no Apple-platform frameworks beyond
// Foundation. It lives in a package so `swift test` can check it in seconds on
// the Mac, without a Simulator or a hand-built Xcode test target.
import PackageDescription

let package = Package(
    name: "FantasyCatCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "FantasyCatCore", targets: ["FantasyCatCore"])],
    targets: [
        .target(name: "FantasyCatCore"),
        .testTarget(name: "FantasyCatCoreTests", dependencies: ["FantasyCatCore"]),
    ]
)
