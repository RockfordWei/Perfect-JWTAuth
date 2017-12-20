import PerfectLib
import PerfectCrypto
import Foundation

public struct UserRecord: Codable {
  public var name = ""
  public var salt = ""
  public var shadow = ""
  public init(name: String, salt: String, shadow: String) {
    self.name = name
    self.salt = salt
    self.shadow = shadow
  }
}

/// *NOTE* All implementation of UDB must be:
/// 1. Thread Safe
/// 2. Yield error when inserting to an existing record
public protocol UserDatabase {
  func insert(user: UserRecord) throws
  func select(username: String) throws -> UserRecord
  func update(user: UserRecord) throws
  func delete(username: String) throws
}

extension Int {
  public func inRange(of: CountableClosedRange<Int>) -> Bool {
    return self >= of.lowerBound && self <= of.upperBound
  }
}
public class AccessManager {

  public enum Exception: Error {
    case OperationFailure
    case CryptoFailure
    case UserExists
    case UserNotExists
    case InvalidLogin
    case LoginFailure
    case TokenFailure
    case InvalidToken
    case Unsupported
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

  /// register a new user record
  public func register(username: String, password: String) throws {
    let usr = username.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
      password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        throw Exception.InvalidLogin
    }
    guard let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
      let salt = String(validatingUTF8: random),
      let shadow = usr.encrypt(_cipher, password: pwd, salt: salt)
      else {
        throw Exception.CryptoFailure
    }
    let u = UserRecord(name: usr, salt: salt, shadow: shadow)
    try _udb.insert(user: u)
  }

  /// update the user password
  public func update(username: String, password: String) throws {
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
    let u = UserRecord(name: usr, salt: salt, shadow: shadow)
    try _udb.update(user: u)
  }

  /// login to generate a valid jwt token
  public func login(username: String, password: String,
                     subject: String = "", timeout: Int = 3600,
                     headers: [String:Any] = [:]) throws -> String {
    let usr = username.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
    password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        throw Exception.InvalidLogin
    }
    let u = try _udb.select(username: usr)
    guard let decodedUsername = u.shadow.decrypt(_cipher, password: pwd, salt: u.salt) else {
      throw Exception.CryptoFailure
    }
    guard decodedUsername == usr else {
      throw Exception.LoginFailure
    }
    let now = time(nil)
    let expiration = now + timeout
    let claims:[String: Any] = [
        "iss":_managerID, "sub": subject, "aud": username,
        "exp": expiration, "nbf": now, "iat": now, "jit": UUID().string
      ]

    guard let jwt = JWTCreator(payload: claims) else {
      throw Exception.TokenFailure
    }

    return try jwt.sign(alg: _alg, key: u.salt, headers: headers)
  }

  /// verify a jwt token
  public func verify(username: String, token: String) throws {
    guard let jwt = JWTVerifier(token) else {
      throw Exception.TokenFailure
    }
    let usr = username.stringByEncodingURL
    guard username.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty else {
        throw Exception.InvalidLogin
    }
    let u = try _udb.select(username: usr)
    let now = time(nil)
    try jwt.verify(algo: _alg, key: HMACKey(u.salt))
    guard let iss = jwt.payload["iss"] as? String, iss == _managerID,
      let aud = jwt.payload["aud"] as? String, aud == username,
      let timeout = jwt.payload["exp"] as? Int, now <= timeout,
      let nbf = jwt.payload["nbf"] as? Int, nbf <= now else {
        throw Exception.TokenFailure
    }
  }

  /// drop a user
  public func drop(username: String) throws {
    try _udb.delete(username: username)
  }
}


