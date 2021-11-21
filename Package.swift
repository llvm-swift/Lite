// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "LiteSupport",
  products: [
    .library(
      name: "LiteSupport",
      targets: ["LiteSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.1.5"),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .upToNextMinor(from: "0.2.4"))
  ],
  targets: [
    .target(
      name: "LiteSupport",
      dependencies: ["Rainbow", "SwiftToolsSupport-auto"]),

    // This needs to be named `lite-test` instead of `lite` because consumers
    // of `lite` should use the target name `lite`.
    .target(
      name: "lite-test",
      dependencies: ["LiteSupport"]),
    .testTarget(
      name: "LiteTests",
      dependencies: ["LiteSupport"]),
  ]
)
