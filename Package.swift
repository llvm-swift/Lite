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
    .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.4.0"),
  ],
  targets: [
    .target(
      name: "LiteSupport",
      dependencies: ["Rainbow", "SPMUtility"]),

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
