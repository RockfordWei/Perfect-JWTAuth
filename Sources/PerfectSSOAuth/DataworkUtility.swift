import PerfectLib
import PerfectCrypto
import Foundation

public enum Exception: Error {
  case Fault(String)
}

public final class DataworkUtility {

  public struct Property {
    public var fieldName = ""
    public var typeName = ""
    public var value: Any
  }
  public static let encoder = JSONEncoder()
  public static func explainProperties<Profile: Codable>(of: Profile) throws -> [Property] {
    let data = try encoder.encode(of)
    guard let json = String.init(bytes: data, encoding: .utf8),
      let payload = try json.jsonDecode() as? [String:Any]
      else {
        throw Exception.Fault("json decoding failure")
    }
    var result:[Property] = []
    for (key, value) in payload {
      let typeName = type(of: value)
      let s = Property(fieldName: key, typeName: "\(typeName)", value: value)
      result.append(s)
    }
    return result
  }
  public typealias KString = String
  public typealias LongString = String
  public static func TypeOf(_ swiftTypeName: String) -> String? {
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
