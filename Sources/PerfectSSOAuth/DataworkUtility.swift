import PerfectLib
import PerfectCrypto
import PerfectThread
import Foundation

/// PerfectSSOAuth Exceptions
public enum Exception: Error {

  /// an error with a readable reason.
  case fault(String)

  /// something about json
  case json

  /// bad user name
  case username

  /// bad password
  case password

  /// encryption failure
  case encryption

  /// digestion failure
  case digestion

  /// access denied
  case access

  /// bad format
  case malformed

  /// bad request
  case request

  /// expired
  case expired

  /// violation
  case violation

  /// record not found
  case inexisting

  /// operation failure
  case operation

  /// unsupported
  case unsupported

  /// connection failure
  case connection
}

/// a log file record
public struct LogRecord: Codable {

  /// record id, suggest to use uuid() to generate a unique record in the system.
  public var id = ""

  /// timestamp
  public var timestamp = ""

  /// login user id, may be "unknown" if the user name is invalid
  public var userId = ""

  /// log event level. see `enum LogLevel` for more information
  public var level = 0

  /// login events. see `enum LoginManagementEvent` for mor information
  public var event = 0

  /// an extra text message for this event, could be nil
  public var message = ""
}

/// a placeholder for log to stdout
public final class StdLogger: LogManager {

  public static func timestamp(_ gmt: Bool = false) -> (String, String) {
    var now = time(nil)
    var t = tm()
    if gmt {
      gmtime_r(&now, &t)
    } else {
      localtime_r(&now, &t)
    }
    return (String(format: "%02d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday),
            String(format: "%02d:%02d:%02d", t.tm_hour, t.tm_min, t.tm_sec))
  }

  public func report(_ userId: String, level: LogLevel, event: LoginManagementEvent, message: String?) {
    let t = StdLogger.timestamp()
    print(t.0, t.1, userId, level, event, message ?? "")
  }
}

/// an embedded file logger
public class FileLogger: LogManager {
  internal let _lock: Threading.Lock
  internal let _path: String
  internal let _gmt: Bool
  internal let encoder: JSONEncoder

  /// constructor
  /// - parameters:
  ///   - path: a local folder to store the log file. **NOTE** the log files will be access.`\(date)`.log under the folder.
  ///   - GMT: if using GMT, true by default. If false, the log filer will apply local times.
  public init(_ path: String, GMT: Bool = true) {
    _lock = Threading.Lock()
    _path = path
    _gmt = GMT
    encoder = JSONEncoder()
  }


  /// report an event
  /// - parameters:
  ///   - userId: login user id, may be "unknown" if the user name is invalid
  ///   - level: log event level. see `enum LogLevel` for more information
  ///   - event: login events. see `enum LoginManagementEvent` for mor information
  ///   - message: an extra text message for this event, could be nil
  public func report(_ userId: String, level: LogLevel = .event, event: LoginManagementEvent, message: String? = nil) {
    let t = StdLogger.timestamp(self._gmt)
    let fileName = "\(_path)/access.\(t.0).log"
    var r = LogRecord()
    r.id = UUID().string
    r.userId = userId
    r.level = level.rawValue
    r.event = event.rawValue
    r.timestamp = t.0 + " " + t.1
    if let msg = message {
      r.message = msg
    }
    _lock.doWithLock {
      do {
        let f = File(fileName)
        try f.open(.append)
        let data = try encoder.encode(r)
        if let content = String(data: data, encoding: .utf8) {
          try f.write(string: content + ",\n")
          f.close()
        }
      } catch {
        print("unable to log \(r)")
      }
    }
  }
}

/// A utility class for Swift - ANSI SQL object mapping
public final class DataworkUtility {

  /// A descriptor of an ANSI SQL table field / column
  public struct Field {

    /// field name
    public var name = ""

    /// field type
    public var `type` = ""

    /// a sample row value
    public var value: Any

    /// a basic constructor - without sample values
    public init(name: String, `type`: String) {
      self.name = name
      self.type = `type`
      self.value = 0
    }

    /// a complete constructor - with a sample value
    public init(name: String, `type`: String, value: Any) {
      self.name = name
      self.type = `type`
      self.value = value
    }
  }

  /// a json encoder for the conversion from a Swift structure to an ANSI SQL table
  public static let encoder = JSONEncoder()
  public static var recyclingSpan = 60 // in seconds.
  /// convert a codable profile to an array of fields
  /// - parameter of: a codable profile to convert
  /// - returns: an array of fields
  /// - throws: Exception
  public static func explainProperties<Profile: Codable>(of: Profile) throws -> [Field] {
    let data = try encoder.encode(of)
    guard let json = String.init(bytes: data, encoding: .utf8),
      let payload = try json.jsonDecode() as? [String:Any]
      else {
        throw Exception.json
    }
    var result:[Field] = []
    for (key, value) in payload {
      let typeName = type(of: value)
      let s = Field(name: key, type: "\(typeName)", value: value)
      result.append(s)
    }
    return result
  }

  /// a simple mapping of Swift data types to ANSI SQL data types.
  /// **NOTE**: `String` has been converted to `VARCHAR(256)`, so please adjust the length if need.
  /// - parameter swiftTypeName: the swift type name to look for
  /// - returns: the ANSI SQL data type name, if possible.
  public static func ANSITypeOf(_ swiftTypeName: String) -> String? {
    let typeMap: [String: String] = [
      "String": "VARCHAR(256)",
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
