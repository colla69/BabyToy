// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "BabyToy",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "BabyToy", targets: ["BabyToy"])
  ],
  targets: [
    .target(name: "BabyToyCore"),
    .executableTarget(name: "BabyToy", dependencies: ["BabyToyCore"]),
    .testTarget(name: "BabyToyCoreTests", dependencies: ["BabyToyCore"]),
  ]
)
