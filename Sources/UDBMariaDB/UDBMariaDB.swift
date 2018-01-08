import PerfectSSOAuth
import Foundation
import MariaDB

typealias Exception = PerfectSSOAuth.Exception
typealias Field = DataworkUtility.Field

extension MySQLStmt {
  public func bindParameter(_ x: Any) throws {
    if x is String, let y = x as? String {
      self.bindParam(y)
    } else if x is Int, let y = x as? Int {
      self.bindParam(y)
    } else if x is UInt64, let y = x as? UInt64 {
      self.bindParam(y)
    } else if x is Double, let y = x as? Double {
      self.bindParam(y)
    } else if x is [Int8], let y = x as? [Int8] {
      self.bindParam(y, length: y.count)
    } else {
      //let tp = type(of: x)
      throw Exception.unsupported
    }
  }
}
public class UDBMariaDB<Profile>: UserDatabase {

  internal let db: MySQL
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let fields: [Field]
  internal var touch: time_t

  internal func autoflush() {
    let now = time(nil)
    if now - touch > DataworkUtility.recyclingSpan {
      flush()
      touch = now
    }
  }

  public init<Profile: Codable>
    (host: String, user: String, password: String,
     database: String, sample: Profile) throws {
    db = MySQL()
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    touch = time(nil)

    guard db.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4"),
      db.connect(host: host, user: user, password: password, db: database) else {
        throw Exception.connection
    }
    let properties = try DataworkUtility.explainProperties(of: sample)
    guard !properties.isEmpty else {
      throw Exception.malformed
    }
    fields = try properties.map { s -> Field in
      guard let tp = DataworkUtility.ANSITypeOf(s.type) else {
        throw Exception.unsupported
      }
      return Field(name: s.name, type: tp)
    }
    let description:[String] = fields.map { "\($0.name) \($0.type)" }
    let fieldDescription = description.joined(separator: ",")
    let sql = """
    CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(80) PRIMARY KEY NOT NULL,
    salt VARCHAR(256), shadow VARCHAR(1024), \(fieldDescription))
    """
    guard db.query(statement: sql) else {
      throw Exception.operation
    }
    let sql2 = """
    CREATE TABLE IF NOT EXISTS tickets (
    id VARCHAR(80) PRIMARY KEY NOT NULL,
    expiration INTEGER)
    """
    guard db.query(statement: sql2) else {
      throw Exception.operation
    }
    let sql3 = """
    CREATE INDEX IF NOT EXISTS ticket_exp ON tickets( expiration)
    """
    guard db.query(statement: sql3) else {
      throw Exception.operation
    }
  }

  deinit {
    db.close()
  }

  public func ban(_ ticket: String, _ expiration: time_t) throws {
    guard expiration > time(nil) else {
      throw Exception.expired
    }
    self.autoflush()

    let sql = "INSERT INTO tickets(id, expiration) VALUES (?, ?)"
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    guard stmt.prepare(statement: sql)
      else {
        throw Exception.operation
    }
    stmt.bindParam(ticket)
    stmt.bindParam(expiration)
    guard stmt.execute() else {
      throw Exception.operation
    }
  }

  public func isRejected(_ ticket: String) -> Bool {
    self.autoflush()

    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    let sql = "SELECT id FROM tickets WHERE id = ? LIMIT 1"
    guard stmt.prepare(statement:sql)
      else {
        return false
    }
    stmt.bindParam(ticket)
    guard stmt.execute() else {
      return false
    }
    return stmt.results().numRows > 0
  }

  internal func flush() {
    let sql = "DELETE FROM tickets WHERE expiration < ?"
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    guard stmt.prepare(statement: sql)
      else {
        return
    }
    stmt.bindParam(time(nil))
    guard stmt.execute() else {
      return
    }
  }

  internal func exists(_ id: String) -> Bool {
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    let sql = "SELECT id FROM users WHERE id = ? LIMIT 1"
    guard stmt.prepare(statement:sql)
      else {
        return false
    }
    stmt.bindParam(id)
    guard stmt.execute() else {
      return false
    }
    return stmt.results().numRows > 0
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    if exists(record.id) {
      throw Exception.violation
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.json
    }
    let properties:[String] = fields.map { $0.name }
    let columns = ["id", "salt", "shadow"] + properties
    let qmarks:[String] = Array.init(repeating: "?", count: columns.count)
    let col = columns.joined(separator: ",")
    let que = qmarks.joined(separator: ",")
    let sql = "INSERT INTO users (\(col)) VALUES(\(que))"
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    guard stmt.prepare(statement: sql)
      else {
        throw Exception.operation
    }
    stmt.bindParam(record.id)
    stmt.bindParam(record.salt)
    stmt.bindParam(record.shadow)
    for p in properties {
      guard let x = dic[p] else { continue }
      try stmt.bindParameter(x)
    }
    guard stmt.execute() else {
      throw Exception.operation
    }
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    guard exists(record.id) else {
      throw Exception.inexisting
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.json
    }
    let properties:[String] = fields.map { $0.name }
    let columns:[String] = fields.map { "\($0.name) = ?" }
    let sentence = columns.joined(separator: ",")
    let sql = "UPDATE users SET salt = ?, shadow = ?, \(sentence) WHERE id = ?"
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    guard stmt.prepare(statement: sql) else {
      throw Exception.operation
    }
    stmt.bindParam(record.salt)
    stmt.bindParam(record.shadow)
    for p in properties {
      guard let x = dic[p] else { continue }
      try stmt.bindParameter(x)
    }
    stmt.bindParam(record.id)
    guard stmt.execute() else {
      throw Exception.operation
    }
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    var u: UserRecord<Profile>? = nil
    let columns:[String] = fields.map { $0.name }
    let col = columns.joined(separator: ",")
    let sql = "SELECT id, salt, shadow, \(col) FROM users WHERE id = ? LIMIT 1"
    let stmt = MySQLStmt(self.db)
    defer { stmt.close() }
    guard stmt.prepare(statement: sql)
      else {
        throw Exception.operation
    }
    stmt.bindParam(id)
    guard stmt.execute() else { throw Exception.operation }
    let fetched = stmt.results().forEachRow { rec in
      let _id = rec[0] as? String
      let _salt = rec[1] as? String
      let _shadow = rec[2] as? String
      var dic: [String: Any] = [:]
      for i in 0 ..< fields.count {
        let j = i + 3
        if let x = rec[j] {
          dic[columns[i]] = x
        }
      }
      guard
        let id = _id, let salt = _salt, let shadow = _shadow,
        dic.count == columns.count else {
          return
      }
      do {
        let json = try dic.jsonEncodedString()
        let data = Data(json.utf8)
        let profile = try decoder.decode(Profile.self, from: data)
        u = UserRecord(id: id, salt: salt, shadow: shadow, profile: profile)
      } catch {
        debugPrint("json failure")
      }
    }
    guard fetched, let v = u else { throw Exception.operation }
    return v
  }

  public func delete(_ id: String) throws {
    guard exists(id) else {
      throw Exception.inexisting
    }
    let stmt = MySQLStmt(db)
    defer { stmt.close() }
    let sql = "DELETE FROM users WHERE id = ?"
    guard stmt.prepare(statement: sql)
      else {
        throw Exception.operation
    }
    stmt.bindParam(id)
    guard stmt.execute() else {
      throw Exception.operation
    }
  }
}
