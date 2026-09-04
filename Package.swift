// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SchnapShot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SchnapShot", targets: ["SchnapShot"])],
    targets: [
        .target(name: "ThumbnailCore"),
        .executableTarget(name: "SchnapShot", dependencies: ["ThumbnailCore"]),
        .testTarget(name: "ThumbnailCoreTests", dependencies: ["ThumbnailCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
