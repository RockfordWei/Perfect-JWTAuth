import PackageDescription
import Foundation

var repos = ["Perfect-Crypto"]
var targets = [Target(name: "PerfectSSOAuth", dependencies: [])]
let excludes: [String]
let db: String
if let database = getenv("DATABASE_DRIVER") {
  db = String(cString: database)
} else {
  db = "ALL"
}
switch db {
case "SQLite":
  repos.append("Perfect-SQLite")
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectSSOAuth"]))
  excludes = ["Sources/UDBJSONFile"]
  break
case "JSONFile":
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectSSOAuth"]))
  excludes = ["Sources/UDBSQLite"]
default:
  repos.append("Perfect-SQLite")
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectSSOAuth"]))
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectSSOAuth"]))
  targets.append(Target(name: "PerfectSSOAuthTests", dependencies: ["PerfectSSOAuth", "UDBJSONFile", "UDBSQLite"]))
  excludes = []
}

let urls: [String]
if let cache = getenv("URL_PERFECT"), let local = String(validatingUTF8: cache) {
  urls = repos.map {"\(local)/\($0)" }
} else {
  urls = repos.map { "https://github.com/PerfectlySoft/\($0).git" }
}
let package = Package(
    name: "PerfectSSOAuth",
    targets: targets,
    dependencies: urls.map { .Package(url: $0, majorVersion: 3) },
    exclude: excludes
)
