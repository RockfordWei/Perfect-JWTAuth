import PackageDescription
import Foundation

let repos = ["Perfect-Crypto", "Perfect-SQLite"]
let urls: [String]
if let cache = getenv("URL_PERFECT"), let local = String(validatingUTF8: cache) {
  urls = repos.map {"\(local)/\($0)" }
} else {
  urls = repos.map { "https://github.com/PerfectlySoft/\($0).git" }
}
let package = Package(
    name: "PerfectSSOAuth",
    targets: [
      Target(name: "PerfectSSOAuth", dependencies: []),
      Target(name: "UDBJSONFile", dependencies: ["PerfectSSOAuth"]),
      Target(name: "UDBSQLite", dependencies: ["PerfectSSOAuth"]),
      Target(name: "PerfectSSOAuthTests", dependencies: ["PerfectSSOAuth", "UDBJSONFile", "UDBSQLite"])
    ],
    dependencies: urls.map { .Package(url: $0, majorVersion: 3) }
)
