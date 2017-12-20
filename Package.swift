// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let repo = "Perfect-Crypto"
let url: String
if let cache = getenv("URL_PERFECT"), let local = String(validatingUTF8: cache) {
  url = "\(local)/\(repo)/.git"
} else {
  url = "https://github.com/PerfectlySoft/\(repo).git"
}
let package = Package(
    name: "PerfectSSOAuth",
    products: [
        .library(
            name: "PerfectSSOAuth",
            targets: ["PerfectSSOAuth", "UDBJSONFile"]),
    ],
    dependencies: [
        .package(url: url, from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "PerfectSSOAuth",
            dependencies: ["PerfectCrypto"]),
        .target(
            name: "UDBJSONFile",
            dependencies: ["PerfectSSOAuth"]),
        .testTarget(
            name: "PerfectSSOAuthTests",
            dependencies: ["PerfectSSOAuth", "UDBJSONFile"]),
    ]
)
