// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VKTurnProxy",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "VKTurnProxy", targets: ["VKTurnProxy"])
    ],
    dependencies: [
        .package(url: "https://github.com/NMSSH/NMSSH.git", from: "2.3.1")
    ],
    targets: [
        .target(
            name: "VKTurnProxy",
            dependencies: ["NMSSH"],
            path: "VKTurnProxy"
        )
    ]
)
