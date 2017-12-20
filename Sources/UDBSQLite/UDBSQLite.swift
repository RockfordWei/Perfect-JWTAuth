import PerfectThread
import PerfectSQLite
import PerfectSSOAuth

public class UDBSQLite: UserDatabase {

  typealias Exception = AccessManager.Exception
  internal let lock: Threading.Lock
  internal let db: SQLite

  public func insert(user: UserRecord) throws {
    if exists(username: user.name) {
      throw Exception.UserExists
    }
    try lock.doWithLock {
      try db.execute(statement: "INSERT INTO users(name, salt, shadow) VALUES(?, ?, ?)"){
        stmt in
        try stmt.bind(position: 1, user.name)
        try stmt.bind(position: 2, user.salt)
        try stmt.bind(position: 3, user.shadow)
      }
    }
  }

  internal func exists(username: String) -> Bool {
    let count = (try? lock.doWithLock {
      var count = 0
      try self.db.forEachRow(statement:
        "SELECT COUNT(name) FROM users WHERE name = ?",
                             doBindings: { stmt in
                              try stmt.bind(position: 1, username)
      }) { rec, i in
        count = rec.columnInt(position: 0)
        }
        return count
      }) ?? 0
    return count > 0
  }
  public func select(username: String) throws -> UserRecord {
    return try lock.doWithLock {
      var u: UserRecord? = nil
      try self.db.forEachRow(statement:
        "SELECT name, salt, shadow FROM users WHERE name = ? LIMIT 1",
                        doBindings: { stmt in
                          try stmt.bind(position: 1, username)
      }) { rec, i in
        if let name = String(rec.columnText(position: 0)),
          let salt = String(rec.columnText(position: 1)),
          let shadow = String(rec.columnText(position: 2)) {
          u = UserRecord(name: name, salt: salt, shadow: shadow)
        }
      }
      guard let v = u else {
        throw Exception.InvalidLogin
      }
      return v
    }
  }

  public func update(user: UserRecord) throws {
    guard exists(username: user.name) else {
      throw Exception.UserNotExists
    }
    try lock.doWithLock {
      try db.execute(statement: "UPDATE users SET salt = ?, shadow = ? WHERE name = ?"){
        stmt in
        try stmt.bind(position: 3, user.name)
        try stmt.bind(position: 1, user.salt)
        try stmt.bind(position: 2, user.shadow)
      }
    }
  }

  public func delete(username: String) throws {
    guard exists(username: username) else {
      throw Exception.UserNotExists
    }
    try lock.doWithLock {
      try db.execute(statement: "DELETE users WHERE name = ?"){
        stmt in
        try stmt.bind(position: 1, username)
      }
    }
  }

  public init(path: String) throws {
    lock = Threading.Lock()
    db = try SQLite(path)
    try db.execute(statement: """
CREATE TABLE IF NOT EXISTS users(
  name TEXT PRIMARY KEY NOT NULL,
  salt TEXT, shadow TEXT)
""")
  }

  deinit {
    db.close()
  }
}

