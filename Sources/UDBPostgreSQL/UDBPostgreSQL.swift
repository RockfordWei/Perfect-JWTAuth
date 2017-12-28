import PerfectThread
import PerfectPostgreSQL
import PerfectSSOAuth
import Foundation

typealias Exception = PerfectSSOAuth.Exception
typealias Field = DataworkUtility.Field

public class UDBPostgreSQL<Profile>: UserDatabase {
  internal let lock: Threading.Lock
  internal let db: PGConnection
  internal let table: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let fields: [Field]

  public init<Profile: Codable>
    (connection: String, table: String, sample: Profile) throws {
    db = PGConnection()
    let status = db.connectdb(connection)
    guard status == .ok else {
      throw Exception.fault("Connection Failure, please check the connection string " + connection)
    }
    lock = Threading.Lock()
    self.table = table
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    let properties = try DataworkUtility.explainProperties(of: sample)
    guard !properties.isEmpty else {
      throw Exception.fault("invalid profile structure")
    }
    fields = try properties.map { s -> Field in
      guard let tp = DataworkUtility.ANSITypeOf(s.type) else {
        throw Exception.fault("incompatible type name: \(s.type)")
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
    let result = try db.execute(statement: sql)
    let s = result.status()
    let r = result.errorMessage()
    result.clear()
    guard s == .commandOK || s == .tuplesOK else {
      throw Exception.fault(r)
    }
  }

  deinit {
    db.close()
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {
    if exists(record.id) {
      throw Exception.fault("user has already registered")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      var dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.fault("json encoding failure")
    }
    dic["id"] = record.id
    dic["salt"] = record.salt
    dic["shadow"] = record.shadow

    try lock.doWithLock {
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
          throw Exception.fault("unexpected field \(columns[i])")
        }
      }
      let col = columns.joined(separator: ",")
      let que = variables.joined(separator: ",")
      sql = "INSERT INTO \(self.table)(\(col)) VALUES(\(que))"
      let result = db.exec(statement: sql, params: values)
      let s = result.status()
      let r = result.errorMessage()
      result.clear()
      guard s == .commandOK || s == .tuplesOK else {
        throw Exception.fault(r)
      }
    }
  }

  public func update<Profile>(_ record: UserRecord<Profile>) throws {
    guard exists(record.id) else {
      throw Exception.fault("user does not exists")
    }
    let data = try encoder.encode(record.profile)
    let bytes:[UInt8] = data.map { $0 }
    guard let json = String(validatingUTF8:bytes),
      var dic = try json.jsonDecode() as? [String: Any] else {
        throw Exception.fault("json encoding failure")
    }
    dic["salt"] = record.salt
    dic["shadow"] = record.shadow

    try lock.doWithLock {
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
          throw Exception.fault("unexpected field: \(col)")
        }
      }
      values.append(record.id)
      let sentence = columns.joined(separator: ",")
      let idNum = properties.count + 1
      let sql = "UPDATE \(table) SET \(sentence) WHERE id = $\(idNum)"
      let result = db.exec(statement: sql, params: values)
      let s = result.status()
      let r = result.errorMessage()
      result.clear()
      guard s == .commandOK || s == .tuplesOK else {
        throw Exception.fault(r)
      }
    }
  }

  public func delete(_ id: String) throws {
    guard exists(id) else {
      throw Exception.fault("user does not exist")
    }
    try lock.doWithLock {
      let sql = "DELETE FROM \(self.table) WHERE id = $1"
      let result = db.exec(statement: sql, params: [id])
      let s = result.status()
      let r = result.errorMessage()
      result.clear()
      guard s == .commandOK || s == .tuplesOK else {
        throw Exception.fault(r)
      }
    }
  }

  public func select<Profile>(_ id: String) throws -> UserRecord<Profile> {
    return try lock.doWithLock  {
      let columns:[String] = fields.map { $0.name }
      let col = columns.joined(separator: ",")
      let  sql = "SELECT id, salt, shadow, \(col) FROM \(self.table) WHERE id = $1 LIMIT 1"
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
          throw Exception.fault("unexpected select result")
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
          throw Exception.fault("incompatible SQL type \(tp)")
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
        throw Exception.fault("json encoding / decoding failure")
      }
    }
  }

  internal func exists(_ id: String) -> Bool {
    return lock.doWithLock {
      let sql = "SELECT id FROM \(self.table) WHERE id = $1 LIMIT 1"
      let res = db.exec(statement: sql, params: [id])
      let count = res.numTuples()
      res.clear()
      return count > 0
    }
  }
}
