import PerfectLib
import PerfectCrypto
import PerfectThread
import Foundation

public enum Exception: Error {
  case Fault(String)
}

public final class DataworkUtility {

  public struct Field {
    public var name = ""
    public var `type` = ""
    public var value: Any
    public init(name: String, `type`: String) {
      self.name = name
      self.type = `type`
      self.value = 0
    }
    public init(name: String, `type`: String, value: Any) {
      self.name = name
      self.type = `type`
      self.value = value
    }
  }
  public static let encoder = JSONEncoder()
  public static func explainProperties<Profile: Codable>(of: Profile) throws -> [Field] {
    let data = try encoder.encode(of)
    guard let json = String.init(bytes: data, encoding: .utf8),
      let payload = try json.jsonDecode() as? [String:Any]
      else {
        throw Exception.Fault("json decoding failure")
    }
    var result:[Field] = []
    for (key, value) in payload {
      let typeName = type(of: value)
      let s = Field(name: key, type: "\(typeName)", value: value)
      result.append(s)
    }
    return result
  }

  public typealias KString = String
  public typealias LongString = String
  public static func ANSITypeOf(_ swiftTypeName: String) -> String? {
    let typeMap: [String: String] = [
      "String": "VARCHAR(256)",
      "KString": "VARCHAR(1024)",
      "LongString": "VARCHAR(65535)",
      "[Int8]": "TEXT", "[CChar]": "TEXT", "[UInt8]": "BLOB",
      "Int": "INTEGER", "UInt": "INTEGER UNSIGNED",
      "Int8": "TINYINT", "UInt8": "TINYINT UNSIGNED",
      "Int16":"SMALLINT", "UInt16": "SMALLINT UNSIGNED",
      "Int32": "INT", "UInt32":"INT UNSIGNED",
      "Int64":"BIGINT", "UInt64": "BIGINT UNSIGNED",
      "Float": "FLOAT", "Double": "DOUBLE",
      "Date": "DATETIME"
    ]
    return typeMap[swiftTypeName]
  }
}
