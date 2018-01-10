//
//  Package.swift
//  PerfectJWTAuth
//
//  Created by Rockford Wei on JAN/9/18.
//	Copyright (C) 2018 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2018 - 2019 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PackageDescription
import Foundation

var repos = ["Perfect-HTTPServer"]
var targets = [Target(name: "PerfectJWTAuth", dependencies: [])]
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
  targets.append(Target(name: "UDBPostgreSQL", dependencies:["PerfectJWTAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBMariaDB"]
case "MariaDB":
  repos.append("Perfect-MariaDB")
  targets.append(Target(name: "UDBMariaDB", dependencies:["PerfectJWTAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBPostgreSQL"]
  break
case "MySQL":
  repos.append("Perfect-MySQL")
  targets.append(Target(name: "UDBMySQL", dependencies:["PerfectJWTAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBSQLite", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
case "SQLite":
  repos.append("Perfect-SQLite")
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectJWTAuth"]))
  excludes = ["Sources/UDBJSONFile", "Sources/UDBMySQL", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
case "JSONFile":
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectJWTAuth"]))
  excludes = ["Sources/UDBSQLite", "Sources/UDBMySQL", "Sources/UDBMariaDB", "Sources/UDBPostgreSQL"]
  break
default:
  repos.append("Perfect-SQLite")
  repos.append("Perfect-MySQL")
  repos.append("Perfect-MariaDB")
  repos.append("Perfect-PostgreSQL")
  targets.append(Target(name: "UDBPostgreSQL", dependencies:["PerfectJWTAuth"]))
  targets.append(Target(name: "UDBMariaDB", dependencies:["PerfectJWTAuth"]))
  targets.append(Target(name: "UDBMySQL", dependencies:["PerfectJWTAuth"]))
  targets.append(Target(name: "UDBSQLite", dependencies:["PerfectJWTAuth"]))
  targets.append(Target(name: "UDBJSONFile", dependencies: ["PerfectJWTAuth"]))
  targets.append(Target(name: "PerfectJWTAuthTests",
  dependencies: ["PerfectJWTAuth", "UDBJSONFile", "UDBSQLite", "UDBMySQL",
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
    name: "PerfectJWTAuth",
    targets: targets,
    dependencies: urls.map { .Package(url: $0, majorVersion: 3) },
    exclude: excludes
)
