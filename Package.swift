// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "NSLogger-NIO",
	products: [
		.library(name: "NSLogger-NIO", targets: ["NSLogger-NIO"]),
		.executable(name: "testServer", targets: ["testServer"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0")
	],

	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "NSLogger-NIO",
			dependencies: ["NIO"]),
		.target(
			name: "testServer",
			dependencies: ["NIO", "NSLogger-NIO"]),
		.testTarget(
			name: "NSLogger-NIO-tests",
			dependencies: ["NSLogger-NIO"]),
	]
)

