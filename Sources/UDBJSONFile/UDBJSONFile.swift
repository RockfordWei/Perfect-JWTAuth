import Foundation
import PerfectThread
import PerfectSSOAuth
import PerfectLib

typealias Exception = PerfectSSOAuth.Exception

public class UDBJSONFile<Profile>: UserDatabase {

  internal let folder: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let lock: Threading.Lock

  internal func path(of: String) -> String {
    return "\(folder)/\(of).json"
  }
  internal func url(of: String) -> URL {
    return URL(fileURLWithPath: path(of: of))
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    let data = try encoder.encode(record)
    try lock.doWithLock {
      if 0 == access(path(of: record.id), 0) {
        throw Exception.fault("record has already registered")
      }
      try data.write(to: self.url(of: record.id))
    }
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    let data: Data = try lock.doWithLock {
      guard 0 == access(path(of: id), 0) else {
        throw Exception.fault("record does not exist")
      }
      return try Data(contentsOf: url(of: id))
    }
    return try decoder.decode(UserRecord.self, from: data)
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    let data = try encoder.encode(record)
    try lock.doWithLock {
      guard 0 == access(path(of: record.id), 0) else {
        throw Exception.fault("record does not exist")
      }
      try data.write(to: url(of: record.id))
    }
  }

  public func delete(_ id: String) throws {
    try lock.doWithLock {
      guard 0 == unlink(path(of: id)) else {
        throw Exception.fault("operation failure")
      }
    }
  }


  public init(directory: String, autocreation: Bool = true, permission: Int = 504) throws {
    if let dir = opendir(directory) {
      closedir(dir)
    } else if autocreation {
      guard 0 == mkdir(directory, mode_t(permission)) else {
        throw Exception.fault("operation failure")
      }
    }
    folder = directory
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    lock = Threading.Lock()
  }
}
