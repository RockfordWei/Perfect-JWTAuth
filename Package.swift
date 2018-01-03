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
case "PostgreSQL":
  repos.append("Perfect-PostgreSQL")
  targets.append(Target(name: "UDBPostgreSQL", dependencies:["PerfectSSOAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBMariaDB"]
case "MariaDB":
  repos.append("Perfect-MariaDB")
  targets.append(Target(name: "UDBMariaDB", dependencies:["PerfectSSOAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBPostgreSQL"]
  break
case "MySQL":
  repos.append("Perfect-MySQL")
  targets.append(Target(name: "UDBMySQL", dependencies:["PerfectSSOAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
case "SQLite":
  repos.append("Perfect-SQLite")
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectSSOAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBMySQL", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
case "JSONFile":
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectSSOAuth"]))
  excludes = ["Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
default:
  repos.append("Perfect-SQLite")
  repos.append("Perfect-MySQL")
  repos.append("Perfect-MariaDB")
  repos.append("Perfect-PostgreSQL")
  targets.append(Target(name: "UDBPostgreSQL", dependencies:["PerfectSSOAuth"]))
  targets.append(Target(name: "UDBMariaDB", dependencies:["PerfectSSOAuth"]))
  targets.append(Target(name: "UDBMySQL", dependencies:["PerfectSSOAuth"]))
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectSSOAuth"]))
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectSSOAuth"]))
  targets.append(Target(name: "PerfectSSOAuthTests",
  dependencies: ["PerfectSSOAuth", "UDBJSONFile", "UDBSQLite", "UDBMySQL",
                 "UDBMariaDB", "UDBPostgreSQL"]))
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
