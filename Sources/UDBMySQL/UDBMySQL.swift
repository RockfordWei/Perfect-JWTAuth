import PerfectThread
import PerfectMySQL
import PerfectSSOAuth

public class UDBMySQL: UserDatabase {

  typealias Exception = AccessManager.Exception
  internal let lock: Threading.Lock
  internal let db: MySQL

  public init(host: String, user: String, password: String, database: String) throws {
    lock = Threading.Lock()
    db = MySQL()
    guard db.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4"),
      db.connect(host: host, user: user, password: password, db: database) else {
      throw Exception.DatabaseConnectionFailure
    }
    guard db.query(statement: """
CREATE TABLE IF NOT EXISTS users(
  name VARCHAR(128) PRIMARY KEY NOT NULL,
  salt VARCHAR(128), shadow VARCHAR(1024))
""") else {
      throw Exception.Reasonable(db.errorMessage())
    }
  }

  deinit {
    db.close()
  }
  public func insert(user: UserRecord) throws {
    if exists(username: user.name) {
      throw Exception.UserExists
    }
    try lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement:
        "INSERT INTO users(name, salt, shadow) VALUES(?, ?, ?)")
        else {
          throw Exception.Reasonable(db.errorMessage())
      }
      stmt.bindParam(user.name)
      stmt.bindParam(user.salt)
      stmt.bindParam(user.shadow)
      guard stmt.execute() else {
        throw Exception.Reasonable(db.errorMessage())
      }
    }
  }

  internal func exists(username: String) -> Bool {
    let count = (try? lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement:
        "SELECT name FROM users WHERE name = ?")
        else {
          throw Exception.Reasonable(db.errorMessage())
      }
      stmt.bindParam(username)
      guard stmt.execute() else {
        throw Exception.Reasonable(db.errorMessage())
      }
      return stmt.results().numRows
    }) ?? 0
    return count > 0
  }

  public func select(username: String) throws -> UserRecord {
    return try lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement:
        "SELECT name, salt, shadow FROM users WHERE name = ? LIMIT 1")
        else {
          throw Exception.Reasonable(db.errorMessage())
      }
      stmt.bindParam(username)
      var _name: String? = nil
      var _salt: String? = nil
      var _shadow: String? = nil
      guard stmt.execute(), (stmt.results().forEachRow { rec in
        _name = rec[0] as? String
        _salt = rec[1] as? String
        _shadow = rec[2] as? String
      }), let name = _name, let salt = _salt, let shadow = _shadow else {
        throw Exception.Reasonable(db.errorMessage())
      }
      return UserRecord(name: name, salt: salt, shadow: shadow)
    }
  }

  public func update(user: UserRecord) throws {
    guard exists(username: user.name) else {
      throw Exception.UserNotExists
    }
    try lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement:
        "UPDATE users SET salt = ?, shadow = ? WHERE name = ?")
        else {
          throw Exception.Reasonable(db.errorMessage())
      }
      stmt.bindParam(user.salt)
      stmt.bindParam(user.shadow)
      stmt.bindParam(user.name)
      guard stmt.execute() else {
        throw Exception.Reasonable(db.errorMessage())
      }
    }
  }

  public func delete(username: String) throws {
    guard exists(username: username) else {
      throw Exception.UserNotExists
    }
    try lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement:
        "DELETE FROM users WHERE name = ?")
        else {
          throw Exception.Reasonable(db.errorMessage())
      }
      stmt.bindParam(username)
      guard stmt.execute() else {
        throw Exception.Reasonable(db.errorMessage())
      }
    }
  }
}

