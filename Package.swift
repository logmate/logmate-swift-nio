// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "logmate",
	products: [
		.library(name: "Logmate", targets: ["Logmate"]),
		.library(name: "LogmateNIO", targets: ["LogmateNIO"]),
		.library(name: "LogmateServer", targets: ["LogmateServer"]),
		.executable(name: "testServer", targets: ["testServer"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.12.0")
	],

	targets: [
		.target(name: "Logmate"),
		.target(name: "LogmateNIO", dependencies: ["Logmate", "NIO"]),
		.target(name: "LogmateServer", dependencies: ["LogmateNIO", "NIO"]),
		.target(name: "LogmateTestsBase", dependencies: ["Logmate"]),
		.testTarget(name: "Logmate-tests", dependencies: ["Logmate","LogmateTestsBase"]),
		.testTarget(name: "LogmateNIO-tests", dependencies: ["LogmateNIO","LogmateTestsBase"]),
		.target(name: "testServer", dependencies: ["LogmateServer", "NIO"]),
	]
)
