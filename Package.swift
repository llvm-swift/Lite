// swift-tools-version:6.1

import PackageDescription

let package = Package(
  name: "LiteSupport",
  platforms: [.macOS(.v15)],
  products: [
    .library(
      name: "LiteSupport",
      targets: ["LiteSupport"]),
    .executable(name: "lite-test", targets: ["lite-test"])
  ],
  dependencies: [
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.1.5"),
    .package(url: "https://github.com/swiftlang/swift-subprocess", branch: "main")
  ],
  targets: [
    .target(
      name: "LiteSupport",
      dependencies: [
        "Rainbow",
        .product(name: "Subprocess", package: "swift-subprocess")
      ]
    ),

    // This needs to be named `lite-test` instead of `lite` because consumers
    // of `lite` should use the target name `lite`.
    .executableTarget(
      name: "lite-test",
      dependencies: ["LiteSupport"]),
    .testTarget(
      name: "LiteTests",
      dependencies: ["LiteSupport"]),
  ]
)
