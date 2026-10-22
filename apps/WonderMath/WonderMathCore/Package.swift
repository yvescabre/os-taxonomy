// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WonderMathCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WonderMathCore", targets: ["WonderMathCore"])
    ],
    targets: [
        .target(name: "WonderMathCore"),
        .testTarget(name: "WonderMathCoreTests", dependencies: ["WonderMathCore"])
    ]
)
