//
//  UDBJSONFile.swift
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

import Foundation
import PerfectJWTAuth
import PerfectLib

typealias Exception = PerfectJWTAuth.Exception

public class UDBJSONFile<Profile>: UserDatabase {

  internal let folder: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder

  internal func path(of: String) -> String {
    return "\(folder)/\(of).json"
  }
  internal func url(of: String) -> URL {
    return URL(fileURLWithPath: path(of: of))
  }

  internal var tickets: [String: time_t] = [:]
  internal var ticketsReversed: [time_t: Set<String>] = [:]
  internal var touch: time_t

  internal func autoflush() {
    let now = time(nil)
    if now - touch > DataworkUtility.recyclingSpan {
      flush()
      touch = now
    }
  }

  public func ban(_ ticket: String, _ expiration: time_t) throws {
    guard expiration > time(nil) else {
      throw Exception.expired
    }
    self.autoflush()
    tickets[ticket] = expiration
    var set: Set<String>
    if let s = ticketsReversed[expiration] {
      set = s
      set.insert(ticket)
    } else {
      set = [ticket]
    }
    ticketsReversed[expiration] = set
  }

  public func isRejected(_ ticket: String) -> Bool {
    self.autoflush()
    if let _ = tickets[ticket] {
      return true
    } else {
      return false
    }
  }

  internal func flush() {
    let keys = ticketsReversed.keys.sorted()
    let now = time(nil)
    for t in keys {
      if now > t { break }
      guard let set = ticketsReversed[t] else { continue }
      set.forEach { _ = tickets.removeValue(forKey: $0) }
      _ = ticketsReversed.removeValue(forKey: t)
    }
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    let data = try encoder.encode(record)
    if 0 == access(path(of: record.id), 0) {
      throw Exception.violation
    }
    try data.write(to: self.url(of: record.id))
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    guard 0 == access(path(of: id), 0) else {
      throw Exception.inexisting
    }
    let data = try Data(contentsOf: url(of: id))
    return try decoder.decode(UserRecord.self, from: data)
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    let data = try encoder.encode(record)
    guard 0 == access(path(of: record.id), 0) else {
      throw Exception.inexisting
    }
    try data.write(to: url(of: record.id))
  }

  public func delete(_ id: String) throws {
    guard 0 == unlink(path(of: id)) else {
      throw Exception.operation
    }
  }


  public init(directory: String, autocreation: Bool = true, permission: Int = 504) throws {
    if let dir = opendir(directory) {
      closedir(dir)
    } else if autocreation {
      guard 0 == mkdir(directory, mode_t(permission)) else {
        throw Exception.operation
      }
    }
    touch = time(nil)

    folder = directory
    encoder = JSONEncoder()
    decoder = JSONDecoder()
  }
}
