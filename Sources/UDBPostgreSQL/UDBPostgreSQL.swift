import PerfectPostgreSQL
import PerfectSSOAuth
import Foundation

typealias Exception = PerfectSSOAuth.Exception
typealias Field = DataworkUtility.Field

public class UDBPostgreSQL<Profile>: UserDatabase {
  internal let db: PGConnection
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
    (connection: String, sample: Profile) throws {
    db = PGConnection()
    let status = db.connectdb(connection)
    guard status == .ok else {
      throw Exception.connection
    }
    touch = time(nil)
    encoder = JSONEncoder()
    decoder = JSONDecoder()
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
    let result = try db.execute(statement: sql)
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
    let sql2 = """
    CREATE TABLE IF NOT EXISTS tickets (
    id VARCHAR(256) PRIMARY KEY NOT NULL,
    expiration INTEGER)
    """
    let result2 = try db.execute(statement: sql2)
    let s2 = result2.status()
    let r2 = result2.errorMessage()
    result2.clear()
    guard s2 == .commandOK || s2 == .tuplesOK else {
      throw Exception.fault(r2)
    }
    let sql3 = """
    CREATE INDEX IF NOT EXISTS ticket_exp ON tickets( expiration)
    """
    let result3 = try db.execute(statement: sql3)
    let s3 = result3.status()
    let r3 = result3.errorMessage()
    result3.clear()
    guard s3 == .commandOK || s3 == .tuplesOK else {
      throw Exception.fault(r3)
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

    let sql = "INSERT INTO tickets(id, expiration) VALUES ($1, $2)"
    let result = db.exec(statement: sql, params: [ticket, expiration])
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
  }

  public func isRejected(_ ticket: String) -> Bool {
    self.autoflush()

    let sql = "SELECT id FROM tickets WHERE id = $1 LIMIT 1"
    let res = db.exec(statement: sql, params: [ticket])
    let count = res.numTuples()
    res.clear()
    return count > 0
  }

  internal func flush() {
    let sql = "DELETE FROM tickets WHERE expiration < $1"
    let result = db.exec(statement: sql, params: [time(nil)])
    result.clear()
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    if exists(record.id) {
      throw Exception.violation
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      var dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.json
    }
    dic["id"] = record.id
    dic["salt"] = record.salt
    dic["shadow"] = record.shadow

    let sql: String
    let properties:[String] = fields.map { $0.name }
    var values: [Any] = []
    let columns = ["id", "salt", "shadow"] + properties
    var variables: [String] = []
    for i in 0 ..< columns.count {
      let j = i + 1
      variables.append("$\(j)")
      if let v = dic[columns[i]] {
        values.append(v)
      } else {
        throw Exception.unsupported
      }
    }
    let col = columns.joined(separator: ",")
    let que = variables.joined(separator: ",")
    sql = "INSERT INTO users (\(col)) VALUES(\(que))"
    let result = db.exec(statement: sql, params: values)
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    guard exists(record.id) else {
      throw Exception.inexisting
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      var dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.json
    }
    dic["salt"] = record.salt
    dic["shadow"] = record.shadow

    let properties:[String] = ["salt" , "shadow"] + fields.map { $0.name }
    var columns:[String] = []
    var values:[Any] = []
    for i in 0 ..< properties.count {
      let col = properties[i]
      let j = i + 1
      columns.append("\(col) = $\(j)")
      if let v = dic[col] {
        values.append(v)
      } else {
        throw Exception.unsupported
      }
    }
    values.append(record.id)
    let sentence = columns.joined(separator: ",")
    let idNum = properties.count + 1
    let sql = "UPDATE users SET \(sentence) WHERE id = $\(idNum)"
    let result = db.exec(statement: sql, params: values)
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
  }

  public func delete(_ id: String) throws {
    guard exists(id) else {
      throw Exception.violation
    }
    let sql = "DELETE FROM users WHERE id = $1"
    let result = db.exec(statement: sql, params: [id])
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    let columns:[String] = fields.map { $0.name }
    let col = columns.joined(separator: ",")
    let  sql = "SELECT id, salt, shadow, \(col) FROM users WHERE id = $1 LIMIT 1"
    let r = db.exec(statement: sql, params: [id])
    let s = r.status()
    let msg = r.errorMessage()
    guard s == .commandOK || s == .tuplesOK,
      r.numTuples() == 1 else {
        r.clear()
        throw Exception.fault(msg)
    }
    guard let uid = r.getFieldString(tupleIndex: 0, fieldIndex: 0),
      let salt = r.getFieldString(tupleIndex: 0, fieldIndex: 1),
      let shadown = r.getFieldString(tupleIndex: 0, fieldIndex: 2),
      uid == id else {
        r.clear()
        throw Exception.operation
    }
    var dic: [String: Any] = [:]
    for i in 0 ..< fields.count {
      let j = i + 3
      let tp = fields[i].type
      if tp.contains(string: "CHAR") {
        dic[fields[i].name] = r.getFieldString(tupleIndex: 0, fieldIndex: j)
      } else if tp == "TINYINT" {
        dic[fields[i].name] = r.getFieldInt8(tupleIndex: 0, fieldIndex: j)
        //dic[fields[i].name] = r.getFieldBool(tupleIndex: 0, fieldIndex: j)
      } else if tp == "SMALLINT" {
        dic[fields[i].name] = r.getFieldInt16(tupleIndex: 0, fieldIndex: j)
      } else if tp == "INT" || tp == "INTEGER" {
        dic[fields[i].name] = r.getFieldInt32(tupleIndex: 0, fieldIndex: j)
      } else if tp == "BIGINT" {
        dic[fields[i].name] = r.getFieldInt64(tupleIndex: 0, fieldIndex: j)
      } else if tp == "FLOAT" {
        dic[fields[i].name] = r.getFieldFloat(tupleIndex: 0, fieldIndex: j)
      } else if tp == "DOUBLE" {
        dic[fields[i].name] = r.getFieldDouble(tupleIndex: 0, fieldIndex: j)
      } else if tp == "BLOB" {
        dic[fields[i].name] = r.getFieldBlob(tupleIndex: 0, fieldIndex: j)
      } else {
        throw Exception.unsupported
      }
    }
    r.clear()
    do {
      let json = try dic.jsonEncodedString()
      let data = Data(json.utf8)
      let profile = try decoder.decode(Profile.self, from: data)
      let u = UserRecord(id: id, salt: salt, shadow: shadown, profile: profile)
      return u
    } catch {
      throw Exception.json
    }
  }

  internal func exists(_ id: String) -> Bool {
    let sql = "SELECT id FROM users WHERE id = $1 LIMIT 1"
    let res = db.exec(statement: sql, params: [id])
    let count = res.numTuples()
    res.clear()
    return count > 0
  }
}
