import PerfectLib
import PerfectCrypto
import PerfectThread
import Foundation

public struct UserRecord: Codable {
  public var username = ""
  public var salt = ""
  public var shadow = ""
}

public protocol UserDatabase {
  func save(user: UserRecord) throws
  func load(username: String) throws -> UserRecord
}

extension Int {
  public func inRange(of: CountableClosedRange<Int>) -> Bool {
    return self >= of.lowerBound && self <= of.upperBound
  }
}
public class AccessManager {

  public enum Exception: Error {
    case CryptoFailure
    case InvalidLogin
    case LoginFailure
    case TokenFailure
    case InvalidToken
  }
  internal let _cipher: Cipher
  internal let _keyIterations: Int
  internal let _digest: Digest
  internal let _saltLength: Int
  internal let _udb: UserDatabase
  internal let _sizeLimitOfCredential: CountableClosedRange<Int>
  internal let _managerID: String
  internal let _alg: JWT.Alg

  public var id: String { return _managerID }
  public init(cipher: Cipher = .aes_256_cbc, keyIterations: Int = 1024,
              digest: Digest = .md5, saltLength: Int = 16,
              sizeLimitOfCredential: CountableClosedRange<Int> = 5...32,
              alg: JWT.Alg = .hs256,
              udb: UserDatabase) {
    _cipher = cipher
    _keyIterations = keyIterations
    _digest = digest
    _saltLength = saltLength
    _sizeLimitOfCredential = sizeLimitOfCredential
    _udb = udb
    _alg = alg
    _managerID = UUID().string
  }

  public func save(username: String, password: String) throws {
    let usr = username.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
      password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty,
      let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
      let salt = String(validatingUTF8: random),
      let shadow = usr.encrypt(_cipher, password: pwd, salt: salt)
      else {
        throw Exception.CryptoFailure
    }
    let u = UserRecord(username: usr, salt: salt, shadow: shadow)
    try _udb.save(user: u)
  }
  public func verify(username: String, password: String,
                     subject: String = "", sessionTime: Int = 3600,
                     headers: [String:Any] = [:]) throws -> String {
    let usr = username.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
    password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        throw Exception.InvalidLogin
    }
    let u = try _udb.load(username: usr)
    guard let decodedUsername = u.shadow.decrypt(_cipher, password: pwd, salt: u.salt) else {
      throw Exception.CryptoFailure
    }
    guard decodedUsername == usr else {
      throw Exception.LoginFailure
    }
    let now = time(nil)
    let expiration = now + sessionTime
    let claims:[String: Any] = [
        "iss":_managerID, "sub": subject, "aud": username,
        "exp": expiration, "nbf": now, "iat": now, "jit": UUID().string
      ]

    guard let jwt = JWTCreator(payload: claims) else {
      throw Exception.TokenFailure
    }

    return try jwt.sign(alg: _alg, key: u.salt, headers: headers)
  }
  public func verify(username: String, token: String) throws {
    guard let jwt = JWTVerifier(token) else {
      throw Exception.TokenFailure
    }
    let usr = username.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty else {
        throw Exception.InvalidLogin
    }
    let u = try _udb.load(username: usr)
    let now = time(nil)
    try jwt.verify(algo: _alg, key: HMACKey(u.salt))
    guard let iss = jwt.payload["iss"] as? String, iss == _managerID,
      let aud = jwt.payload["aud"] as? String, aud == username,
      let timeout = jwt.payload["exp"] as? Int, now <= timeout,
      let nbf = jwt.payload["nbf"] as? Int, nbf <= now else {
        throw Exception.TokenFailure
    }
    debugPrint(jwt.payload)
  }
}

public class EmbeddedUDB: UserDatabase {

  public enum Exception: Error {
    case InvalidPath
    case DeletionFailure
  }

  internal let folder: String
  internal let encoder: JSONEncoder
  internal let decoder: JSONDecoder
  internal let lock: Threading.Lock
  public init(directory: String, autocreation: Bool = true, permission: Int = 504) throws {
    if let dir = opendir(directory) {
      closedir(dir)
    } else if autocreation {
      guard 0 == mkdir(directory, mode_t(permission)) else {
        throw Exception.InvalidPath
      }
    }
    folder = directory
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    lock = Threading.Lock()
  }
  internal func url(of: String) -> URL {
    let u = of.stringByEncodingURL
    return URL(fileURLWithPath: "\(folder)/\(u).json")
  }
  public func save(user: UserRecord) throws {
    let data = try encoder.encode(user)
    try lock.doWithLock {
      try data.write(to: url(of: user.username))
    }
  }

  public func load(username: String) throws -> UserRecord {
    let data: Data = try lock.doWithLock {
      return try Data(contentsOf: url(of: username))
    }
    return try decoder.decode(UserRecord.self, from: data)
  }

  public func drop(username: String) throws {
    let u = username.stringByEncodingURL
    try lock.doWithLock {
      guard 0 == unlink("\(folder)/\(u).json") else {
        throw Exception.DeletionFailure
      }
    }
  }
}

