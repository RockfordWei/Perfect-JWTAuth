import PerfectLib
import PerfectCrypto
import Foundation

public struct UserRecord<Profile>: Codable where Profile: Codable {
  public var id = ""
  public var salt = ""
  public var shadow = ""
  public var profile: Profile
  public init(id: String, salt: String, shadow: String, profile: Profile) {
    self.id = id
    self.salt = salt
    self.shadow = shadow
    self.profile = profile
  }
}

/// *NOTE* All implementation of UDB must be:
/// 1. Thread Safe
/// 2. Yield error when inserting to an existing record
public protocol UserDatabase {
  func insert<Profile>(_ record: UserRecord<Profile>) throws
  func select<Profile>(_ id: String) throws -> UserRecord<Profile>
  func update<Profile>(_ record: UserRecord<Profile>) throws
  func delete(_ id: String) throws
}

extension Int {
  public func inRange(of: CountableClosedRange<Int>) -> Bool {
    return self >= of.lowerBound && self <= of.upperBound
  }
}

public class AccessManager<Profile> where Profile: Codable {

  internal let _cipher: Cipher
  internal let _keyIterations: Int
  internal let _digest: Digest
  internal let _saltLength: Int
  internal let _sizeLimitOfCredential: CountableClosedRange<Int>
  internal let _managerID: String
  internal let _alg: JWT.Alg

  typealias U = UserRecord<Profile>
  internal let _insert: (_ record: U ) throws -> Void
  internal let _select: (_ id: String) throws -> U
  internal let _update: (_ record: U) throws -> Void
  internal let _delete: (_ id: String) throws -> Void

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
    _alg = alg
    _managerID = UUID().string
    _insert = udb.insert
    _select = udb.select
    _update = udb.update
    _delete = udb.delete
  }

  /// register a new user record
  public func register(id: String, password: String, profile: Profile) throws {
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        throw Exception.Fault("invalid login")
    }
    guard let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
      let salt = String(validatingUTF8: random),
      let shadow = usr.encrypt(_cipher, password: pwd, salt: salt)
      else {
        throw Exception.Fault("crypto failure")
    }
    let u = UserRecord<Profile>(id: usr, salt: salt, shadow: shadow, profile: profile)
    try _insert(u)
  }

  public func update(id: String, password: String) throws {
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty,
      let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
      let salt = String(validatingUTF8: random),
      let shadow = usr.encrypt(_cipher, password: pwd, salt: salt)
      else {
        throw Exception.Fault("crypto failure")
    }
    var u = try self._select(id)
    u.salt = salt
    u.shadow = shadow
    try self._update(u)
  }

  /// update the user password
  public func update(id: String, profile: Profile) throws {
    let usr = id.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty
      else {
        throw Exception.Fault("invalid login")
    }
    var u = try self._select(id)
    u.profile = profile
    try self._update(u)
  }

  /// login to generate a valid jwt token
  public func login(id: String, password: String,
                     subject: String = "", timeout: Int = 3600,
                     headers: [String:Any] = [:]) throws -> String {
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
    password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        throw Exception.Fault("invalid login")
    }
    let u = try _select(usr)
    guard
      let decodedUsername = u.shadow.decrypt(_cipher, password: pwd, salt: u.salt),
      decodedUsername == usr
      else {
      throw Exception.Fault("crypto failure")
    }
    let now = time(nil)
    let expiration = now + timeout
    let claims:[String: Any] = [
        "iss":_managerID, "sub": subject, "aud": id,
        "exp": expiration, "nbf": now, "iat": now, "jit": UUID().string
      ]

    guard let jwt = JWTCreator(payload: claims) else {
      throw Exception.Fault("token failure")
    }

    return try jwt.sign(alg: _alg, key: u.salt, headers: headers)
  }

  /// verify a jwt token
  public func verify(id: String, token: String) throws {
    guard let jwt = JWTVerifier(token) else {
      throw Exception.Fault("token failure")
    }
    let usr = id.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty else {
        throw Exception.Fault("invalid login")
    }
    let u = try _select(usr)
    let now = time(nil)
    try jwt.verify(algo: _alg, key: HMACKey(u.salt))
    guard let iss = jwt.payload["iss"] as? String, iss == _managerID,
      let aud = jwt.payload["aud"] as? String, aud == id,
      let timeout = jwt.payload["exp"] as? Int, now <= timeout,
      let nbf = jwt.payload["nbf"] as? Int, nbf <= now else {
        throw Exception.Fault("token failure")
    }
  }

  public func load(id: String) throws -> Profile {
    return try _select(id).profile
  }
  
  /// drop a user
  public func drop(id: String) throws {
    try _delete(id)
  }
}


