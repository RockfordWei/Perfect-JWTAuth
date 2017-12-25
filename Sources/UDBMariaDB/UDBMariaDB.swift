import PerfectThread
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
      let tp = type(of: x)
      throw Exception.Fault("incompatible type: \(tp)")
    }
  }
}
public class UDBMariaDB<Profile>: UserDatabase {

  internal let lock: Threading.Lock
  internal let db: MySQL
  internal let table: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let fields: [Field]

  public init<Profile: Codable>
    (host: String, user: String, password: String,
     database: String, table: String, sample: Profile) throws {
    lock = Threading.Lock()
    db = MySQL()
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    guard db.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4"),
      db.connect(host: host, user: user, password: password, db: database) else {
        throw Exception.Fault("connection failure")
    }
    self.table = table
    let properties = try DataworkUtility.explainProperties(of: sample)
    guard !properties.isEmpty else {
      throw Exception.Fault("invalid profile structure")
    }
    fields = try properties.map { s -> Field in
      guard let tp = DataworkUtility.ANSITypeOf(s.type) else {
        throw Exception.Fault("incompatible type name: \(s.type)")
      }
      return Field(name: s.name, type: tp)
    }
    let description:[String] = fields.map { "\($0.name) \($0.type)" }
    let fieldDescription = description.joined(separator: ",")
    let sql = """
    CREATE TABLE IF NOT EXISTS \(table)(
    id VARCHAR(80) PRIMARY KEY NOT NULL,
    salt VARCHAR(256), shadow VARCHAR(1024), \(fieldDescription))
    """
    guard db.query(statement: sql) else {
      throw Exception.Fault("table creation failure")
    }
  }

  deinit {
    db.close()
  }

  internal func exists(_ id: String) -> Bool {
    let count = (try? lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      let sql = "SELECT id FROM \(self.table) WHERE id = ? LIMIT 1"
      guard stmt.prepare(statement:sql)
        else {
          throw Exception.Fault(db.errorMessage())
      }
      stmt.bindParam(id)
      guard stmt.execute() else {
        throw Exception.Fault(db.errorMessage())
      }
      return stmt.results().numRows
      }) ?? 0
    return count > 0
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    if exists(record.id) {
      throw Exception.Fault("user has already registered")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.Fault("json encoding failure")
    }
    try lock.doWithLock {
      let properties:[String] = fields.map { $0.name }
      let columns = ["id", "salt", "shadow"] + properties
      let qmarks:[String] = Array.init(repeating: "?", count: columns.count)
      let col = columns.joined(separator: ",")
      let que = qmarks.joined(separator: ",")
      let sql = "INSERT INTO \(self.table)(\(col)) VALUES(\(que))"
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement: sql)
        else {
          throw Exception.Fault(db.errorMessage())
      }
      stmt.bindParam(record.id)
      stmt.bindParam(record.salt)
      stmt.bindParam(record.shadow)
      for p in properties {
        guard let x = dic[p] else { continue }
        try stmt.bindParameter(x)
      }
      guard stmt.execute() else {
        throw Exception.Fault(db.errorMessage())
      }
    }
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    guard exists(record.id) else {
      throw Exception.Fault("user does not exists")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.Fault("json encoding failure")
    }
    try lock.doWithLock {
      let properties:[String] = fields.map { $0.name }
      let columns:[String] = fields.map { "\($0.name) = ?" }
      let sentence = columns.joined(separator: ",")
      let sql = "UPDATE \(table) SET salt = ?, shadow = ?, \(sentence) WHERE id = ?"
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      guard stmt.prepare(statement: sql) else {
        throw Exception.Fault(db.errorMessage())
      }
      stmt.bindParam(record.salt)
      stmt.bindParam(record.shadow)
      for p in properties {
        guard let x = dic[p] else { continue }
        try stmt.bindParameter(x)
      }
      stmt.bindParam(record.id)
      guard stmt.execute() else {
        throw Exception.Fault(db.errorMessage())
      }
    }
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    return try lock.doWithLock {
      var u: UserRecord<Profile>? = nil
      let columns:[String] = fields.map { $0.name }
      let col = columns.joined(separator: ",")
      let sql = "SELECT id, salt, shadow, \(col) FROM \(self.table) WHERE id = ? LIMIT 1"
      let stmt = MySQLStmt(self.db)
      defer { stmt.close() }
      guard stmt.prepare(statement: sql)
        else {
          throw Exception.Fault(self.db.errorMessage())
      }
      stmt.bindParam(id)
      guard stmt.execute() else { throw Exception.Fault(self.db.errorMessage())}
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
      guard fetched, let v = u else { throw Exception.Fault(self.db.errorMessage())}
      return v
    }
  }

  public func delete(_ id: String) throws {
    guard exists(id) else {
      throw Exception.Fault("user does not exist")
    }
    try lock.doWithLock {
      let stmt = MySQLStmt(db)
      defer { stmt.close() }
      let sql = "DELETE FROM \(self.table) WHERE id = ?"
      guard stmt.prepare(statement: sql)
        else {
          throw Exception.Fault(db.errorMessage())
      }
      stmt.bindParam(id)
      guard stmt.execute() else {
        throw Exception.Fault(db.errorMessage())
      }
    }
  }
}
