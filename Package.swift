// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwiftAudio",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "SwiftAudioEx",
            targets: ["SwiftAudioEx"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftAudioEx",
            dependencies: [],
            path: "SwiftAudioEx/Classes")
    ]
)
