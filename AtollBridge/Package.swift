// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtollBridge",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "AtollBridge", targets: ["AtollBridge"])],
    targets: [.executableTarget(name: "AtollBridge")]
)
