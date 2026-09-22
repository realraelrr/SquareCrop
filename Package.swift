// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SquareCrop",
  defaultLocalization: "en",
  platforms: [.iOS(.v17)],
  products: [.library(name: "SquareCrop", targets: ["SquareCrop"])],
  targets: [
    .target(name: "SquareCrop", resources: [.process("Resources")]),
    .testTarget(name: "SquareCropTests", dependencies: ["SquareCrop"]),
  ],
  swiftLanguageModes: [.v6]
)
