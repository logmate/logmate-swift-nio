// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "logmate-swift-nio",
	products: [
		.library(name: "LogmateNIO", targets: ["LogmateNIO"]),
		.executable(name: "testServer", targets: ["testServer"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0")
	],

	targets: [
		.target(
			name: "LogmateNIO",
			dependencies: ["NIO"]),
		.testTarget(
			name: "LogmateNIO-tests",
			dependencies: ["LogmateNIO"]),
		.target(
			name: "testServer",
			dependencies: ["NIO", "LogmateNIO"]),
	]
)
