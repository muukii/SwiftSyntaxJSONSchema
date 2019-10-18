// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftJSONSyntax",
  products: [
    .executable(name: "SwiftSyntaxJSONSchema", targets: ["SwiftJSONSyntax"]),
    .library(name: "OpenAPIKit", targets: ["OpenAPIKit"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-syntax.git", .exact("0.50100.0")),
    .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.3.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "OpenAPIKit",
      dependencies: []),
    .target(
      name: "SwiftJSONSyntax",
      dependencies: ["OpenAPIKit", "SwiftSyntax", "SPMUtility"]),
    .testTarget(
      name: "SwiftJSONSyntaxTests",
      dependencies: ["SwiftJSONSyntax"]),
  ]
)
