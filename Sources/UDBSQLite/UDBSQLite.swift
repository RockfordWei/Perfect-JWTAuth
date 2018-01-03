import PerfectSQLite
import PerfectSSOAuth
import Foundation

typealias Exception = PerfectSSOAuth.Exception
typealias Field = DataworkUtility.Field

public class UDBSQLite<Profile>: UserDatabase {
  internal let db: SQLite
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
  
  /// Create a database connection and attach the user table
  /// - parameters:
  ///   - path: the file path of the sqlite3 database
  ///   - table: the table name of the user record
  ///   - sample: a sample profile for table creation
  /// - throws: Exception
  public init<Profile: Codable>(path: String, sample: Profile) throws {
    db = try SQLite(path)
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    touch = time(nil)

    let properties = try DataworkUtility.explainProperties(of: sample)
    guard !properties.isEmpty else {
      throw Exception.fault("invalid profile structure")
    }
    fields = try properties.map { s -> Field in
      let tp = s.type
      let typeName: String
      if tp.contains(string: "[") {
        typeName = "BLOB"
      } else if tp.contains(string: "Int") {
        typeName = "INTEGER"
      } else if tp.contains(string: "Float") || tp.contains(string: "Double") {
        typeName = "REAL"
      } else if tp == "String" {
        typeName = "TEXT"
      } else {
        throw Exception.fault("incompatible type name: \(tp)")
      }
      return Field(name: s.name, type: typeName)
    }
    let description:[String] = fields.map { "\($0.name) \($0.type)" }
    let fieldDescription = description.joined(separator: ",")
    let sql = """
    CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY NOT NULL,
    salt TEXT, shadow TEXT, \(fieldDescription))
    """
    try db.execute(statement: sql)
    try db.execute(statement: """
    CREATE TABLE IF NOT EXISTS tickets (
    id TEXT PRIMARY KEY NOT NULL,
    expiration INTEGER)
    """)
    try db.execute(statement: """
    CREATE INDEX IF NOT EXISTS ticket_exp ON tickets( expiration)
    """)
  }

  deinit {
    db.close()
  }

  public func issue(_ ticket: String, _ expiration: time_t) throws {
    guard expiration > time(nil) else {
      throw Exception.fault("ticket has already expired")
    }
    self.autoflush()

    try db.execute(statement: "INSERT INTO tickets(id, expiration) VALUES (?, ?)") {
      stmt in
      try stmt.bind(position: 1, ticket)
      try stmt.bind(position: 2, expiration)
    }
  }

  public func cancel(_ ticket: String) throws {
    self.autoflush()

    try db.execute(statement: "DELETE FROM tickets WHERE id = ?") {
      stmt in
      try stmt.bind(position: 1, ticket)
    }
  }

  public func isValid(_ ticket: String) -> Bool {
    self.autoflush()

    var count = 0
    let sql = "SELECT id FROM tickets WHERE id = ? LIMIT 1"
    try? self.db.forEachRow(statement: sql,
                           doBindings: { stmt in
                            try stmt.bind(position: 1, ticket)
    }) { _, _ in
      count += 1
    }
    return count > 0
  }

  internal func flush() {
    try? db.execute(statement: "DELETE FROM tickets WHERE expiration < ?") {
      stmt in
      try stmt.bind(position: 1, time(nil))
    }
  }

  internal func exists(_ id: String) -> Bool {
    var count = 0
    let sql = "SELECT id FROM users WHERE id = ? LIMIT 1"
    try? self.db.forEachRow(statement: sql,
                           doBindings: { stmt in
                            try stmt.bind(position: 1, id)
    }) { _, _ in
      count += 1
    }
    return count > 0
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    if exists(record.id) {
      throw Exception.fault("user has already registered")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.fault("json encoding failure")
    }
    let properties:[String] = fields.map { $0.name }
    let columns = ["id", "salt", "shadow"] + properties
    let qmarks:[String] = Array.init(repeating: "?", count: columns.count)
    let col = columns.joined(separator: ",")
    let que = qmarks.joined(separator: ",")
    let sql = "INSERT INTO users (\(col)) VALUES(\(que))"
    try db.execute(statement: sql){
      stmt in
      try stmt.bind(position: 1, record.id)
      try stmt.bind(position: 2, record.salt)
      try stmt.bind(position: 3, record.shadow)
      for i in 0 ..< fields.count {
        let f = fields[i]
        let j = i + 4
        switch f.type {
        case "TEXT":
          let s = dic[f.name] as? String ?? ""
          try stmt.bind(position: j, s)
          break
        case "REAL":
          let s = dic[f.name] as? Double ?? 0
          try stmt.bind(position: j, s)
          break
        case "INTEGER":
          let s = dic[f.name] as? Int ?? 0
          try stmt.bind(position: j, s)
          break
        default:
          throw Exception.fault("incompatible value type")
        }
      }
    }
  }
  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    var u: UserRecord<Profile>? = nil
    let columns:[String] = fields.map { $0.name }
    let col = columns.joined(separator: ",")
    let sql = "SELECT id, salt, shadow, \(col) FROM users WHERE id = ? LIMIT 1"
    try self.db.forEachRow(statement: sql,
                           doBindings: { stmt in
                            try stmt.bind(position: 1, id)
    }) { rec, _ in
      let id = rec.columnText(position: 0)
      let salt = rec.columnText(position: 1)
      let shadow = rec.columnText(position: 2)
      var dic: [String: Any] = [:]
      for i in 0 ..< fields.count {
        let fname = fields[i].name
        let j = i + 3
        switch fields[i].type {
        case "TEXT":
          dic[fname] = rec.columnText(position: j)
          break
        case "INTEGER":
          dic[fname] = rec.columnInt(position: j)
        case "REAL":
          dic[fname] = rec.columnDouble(position: j)
        default:
          throw Exception.fault("unexpected column type: \(fields[i].type)")
        }
      }
      let json = try dic.jsonEncodedString()
      let data = Data(json.utf8)
      let profile = try decoder.decode(Profile.self, from: data)
      u = UserRecord(id: id, salt: salt, shadow: shadow, profile: profile)
    }
    guard let v = u else {
      throw Exception.fault("record not found")
    }
    return v
  }

  public func delete(_ id: String) throws {
    guard exists(id) else {
      throw Exception.fault("user does not exists")
    }
    let sql = "DELETE FROM users WHERE id = ?"
    try db.execute(statement: sql){
      stmt in
      try stmt.bind(position: 1, id)
    }
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    guard exists(record.id) else {
      throw Exception.fault("user does not exists")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      let dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.fault("json encoding failure")
    }
    let columns:[String] = fields.map { "\($0.name) = ?" }
    let sentence = columns.joined(separator: ",")
    let sql = "UPDATE users SET salt = ?, shadow = ?, \(sentence) WHERE id = ?"
    try db.execute(statement: sql){
      stmt in
      try stmt.bind(position: 1, record.salt)
      try stmt.bind(position: 2, record.shadow)
      for i in 0 ..< fields.count {
        let f = fields[i]
        let j = i + 3
        switch f.type {
        case "TEXT":
          let s = dic[f.name] as? String ?? ""
          try stmt.bind(position: j, s)
          break
        case "REAL":
          let s = dic[f.name] as? Double ?? 0
          try stmt.bind(position: j, s)
          break
        case "INTEGER":
          let s = dic[f.name] as? Int ?? 0
          try stmt.bind(position: j, s)
          break
        case "BLOB":
          let s = dic[f.name] as? [Int8] ?? []
          try stmt.bind(position:j, s)
        default:
          throw Exception.fault("incompatible value type")
        }
      }
      try stmt.bind(position: fields.count + 3, record.id)
    }
  }
}
