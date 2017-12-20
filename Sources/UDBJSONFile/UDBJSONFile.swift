import Foundation
import PerfectThread
import PerfectSSOAuth

public class UDBJSONFile: UserDatabase {

  internal let folder: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let lock: Threading.Lock

  typealias Exception = AccessManager.Exception

  internal func path(of: String) -> String {
    return "\(folder)/\(of).json"
  }
  internal func url(of: String) -> URL {
    return URL(fileURLWithPath: path(of: of))
  }

  public func insert(user: UserRecord) throws {
    let data = try encoder.encode(user)
    try lock.doWithLock {
      if 0 == access(path(of: user.name), 0) {
        throw Exception.UserExists
      }
      try data.write(to: self.url(of: user.name))
    }
  }

  public func select(username: String) throws -> UserRecord {
    let data: Data = try lock.doWithLock {
      guard 0 == access(path(of: username), 0) else {
        throw Exception.UserNotExists
      }
      return try Data(contentsOf: url(of: username))
    }
    return try decoder.decode(UserRecord.self, from: data)
  }

  public func update(user: UserRecord) throws {
    let data = try encoder.encode(user)
    try lock.doWithLock {
      guard 0 == access(path(of: user.name), 0) else {
        throw Exception.UserNotExists
      }
      try data.write(to: url(of: user.name))
    }
  }

  public func delete(username: String) throws {
    try lock.doWithLock {
      guard 0 == unlink(path(of: username)) else {
        throw Exception.OperationFailure
      }
    }
  }


  public init(directory: String, autocreation: Bool = true, permission: Int = 504) throws {
    if let dir = opendir(directory) {
      closedir(dir)
    } else if autocreation {
      guard 0 == mkdir(directory, mode_t(permission)) else {
        throw Exception.OperationFailure
      }
    }
    folder = directory
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    lock = Threading.Lock()
  }
}
