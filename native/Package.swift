// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QRPocket",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "QR Pocket", targets: ["QRPocket"])],
    targets: [
        .target(name: "QRPocketCore", path: "Sources/Core"),
        .executableTarget(name: "QRPocket", dependencies: ["QRPocketCore"], path: "Sources/App"),
        .testTarget(name: "CoreTests", dependencies: ["QRPocketCore"], path: "Tests/CoreTests"),
        .testTarget(name: "AppTests", dependencies: ["QRPocket"], path: "Tests/AppTests")
    ]
)
