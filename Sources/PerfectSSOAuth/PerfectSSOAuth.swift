import PerfectLib
import PerfectCrypto
import Foundation

/// A container structure to hold a user record.
public struct UserRecord<Profile>: Codable where Profile: Codable {

  /// user name or email as the user id, must be valid in terms of character set and length
  public var id = ""

  /// an automatic generated string for encryption
  public var salt = ""

  /// the CMS key to store in the record other than save the password itself
  public var shadow = ""

  /// user profile - customizable, must be flat (no nested structures allowed)
  public var profile: Profile

  /// constructor
  /// - parameters:
  ///   - id: user name or email as the user id, must be valid in terms of character set and length
  ///   - salt: an automatic generated string for encryption
  ///   - shadow: the CMS key to store in the record other than save the password itself
  ///   - profile: user profile - customizable, must be flat (no nested structures allowed)
  public init(id: String, salt: String, shadow: String, profile: Profile) {
    self.id = id
    self.salt = salt
    self.shadow = shadow
    self.profile = profile
  }
}

/// login events
public enum LoginManagementEvent: Int {

  /// the user is trying to log in
  case login = 0

  /// the user is trying to register
  case registration = 1

  /// the user is presenting a JWT token to get access
  case verification = 2

  /// the use is trying to log out - may be skipped - empty jwt will do this
  case logoff = 3

  /// the user is trying to close his/her record
  case unregistration = 4

  /// the user is trying to update profile or password
  case updating = 5

  /// there is a system event
  case system = 6
}

/// log event level
public enum LogLevel: Int {

  /// a regular event
  case event = 0

  /// some unusual user behaviours
  case warning = 1

  /// the operation could not be completed internally
  case critical = 2

  /// system failure
  case fault = 3
}

/// general interface of a log file writer
public protocol LogManager {

  /// report a login event
  /// - parameters:
  ///   - userId: user id, could be "unknown" if the user id is invalid
  ///   - level: log event level. see `enum LogLevel` for more information
  ///   - event: login events. see `enum LoginManagementEvent` for mor information
  ///   - message: an extra message for this event, could be nil
  func report(_ userId: String, level: LogLevel, event: LoginManagementEvent, message: String?)
}

/// A general protocol for a user database, UDB in short.
/// *NOTE* All implementation of UDB must be:
/// 1. Thread Safe
/// 2. Yield error when inserting to an existing record
public protocol UserDatabase {

  /// insert a new user record to the database
  /// - parameter record: a user record to save
  /// - throws: Exception
  func insert<Profile>(_ record: UserRecord<Profile>) throws

  /// retrieve a user record by its id
  /// - parameter id: the user id
  /// - returns: a user record instance
  /// - throws: Exception
  func select<Profile>(_ id: String) throws -> UserRecord<Profile>

  /// update an existing user record to the database
  /// - parameter record: a user record to save
  /// - throws: Exception
  func update<Profile>(_ record: UserRecord<Profile>) throws

  /// delete an existing user record by its id
  /// - parameter id: the user id
  /// - throws: Exception
  func delete(_ id: String) throws
}

extension Int {
  /// check if the current value is in a range convienently
  /// - parameters:
  ///   - of: a closed range
  /// - returns: true for in range and false for out of range.
  public func inRange(of: CountableClosedRange<Int>) -> Bool {
    return self >= of.lowerBound && self <= of.upperBound
  }
}

/// a generic Login Manager
public class LoginManager<Profile> where Profile: Codable {

  internal let _cipher: Cipher
  internal let _keyIterations: Int
  internal let _digest: Digest
  internal let _saltLength: Int
  internal let _sizeLimitOfCredential: CountableClosedRange<Int>
  internal let _managerID: String
  internal let _alg: JWT.Alg
  internal let _log: LogManager

  typealias U = UserRecord<Profile>
  internal let _insert: (_ record: U ) throws -> Void
  internal let _select: (_ id: String) throws -> U
  internal let _update: (_ record: U) throws -> Void
  internal let _delete: (_ id: String) throws -> Void

  /// every instance of LoginManager has a unique manager id, in form of uuid
  public var id: String { return _managerID }

  /// constructor of a Login Manager
  /// - parameters:
  ///   - cipher: a cipher algorithm to do the password encryption. AES_252_CBC by default.
  ///   - keyIterations: key iteration times for encryption, 1024 by default.
  ///   - digest: digest algorithm for encryption, MD5 by default.
  ///   - saltLength: length to generate the salt string, 16 by default.
  ///   - sizeLimitOfCredential: a closed range of password length, [5, 80] by default.
  ///   - alg: JWT token generation algorithm, HS256 by default
  ///   - udb: a user database to attache
  ///   - log: a log manager if applicable, default nil for logging to the console.
  public init(cipher: Cipher = .aes_256_cbc, keyIterations: Int = 1024,
              digest: Digest = .md5, saltLength: Int = 16,
              sizeLimitOfCredential: CountableClosedRange<Int> = 5...80,
              alg: JWT.Alg = .hs256,
              udb: UserDatabase,
              log: LogManager? = nil) {
    _cipher = cipher
    _keyIterations = keyIterations
    _digest = digest
    _saltLength = saltLength
    _sizeLimitOfCredential = sizeLimitOfCredential
    _alg = alg
    if let lg = log {
      _log = lg
    } else {
      _log = StdLogger()
    }
    _managerID = UUID().string
    _insert = udb.insert
    _select = udb.select
    _update = udb.update
    _delete = udb.delete
  }

  /// register a new user record. Would log a register event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - password: the user password, will be automatically encoded by URL constraints
  ///   - profile: the user profile to attach
  /// - throws: Exception
  public func register(id: String, password: String, profile: Profile) throws {
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        _log.report("unknown", level: .warning, event: .registration,
          message: "invalid registration attempt '\(id)'/'\(password)'")
        throw Exception.fault("invalid login")
    }
    guard let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
      let salt = String(validatingUTF8: random),
      let shadow = usr.encrypt(_cipher, password: pwd, salt: salt)
      else {
        _log.report(id, level: .critical, event: .registration,
                    message: "unable to register '\(id)'/'\(password)' because of encryption failure")
        throw Exception.fault("crypto failure")
    }
    let u = UserRecord<Profile>(id: usr, salt: salt, shadow: shadow, profile: profile)
    do {
      try _insert(u)
    } catch Exception.fault(let message) {
      _log.report(id, level: .critical, event: .registration,
                  message: "unable to register '\(id)'/'\(password)': \(message)")
      throw Exception.fault(message)
    }
    _log.report(id, level: .event, event: .registration, message: "user registered")
  }

  /// update a user's password. Would log an updating password event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - password: the user's new password, will be automatically encoded by URL constraints
  /// - throws: Exception
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
        _log.report("unknown", level: .warning, event: .updating,
                    message: "invalid update attempt '\(id)'/'\(password)'")
        throw Exception.fault("crypto failure")
    }
    do {
      var u = try self._select(id)
      u.salt = salt
      u.shadow = shadow
      try self._update(u)
    } catch Exception.fault(let message) {
      _log.report(id, level: .critical, event: .updating,
                  message: "unable to update '\(id)'/'\(password)': \(message)")
      throw Exception.fault(message)
    }
    _log.report(id, level: .event, event: .updating, message: "password updated")
  }

  /// update a user's profile. Would log an updating profile event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - profile: the user's new profile
  /// - throws: Exception
  public func update(id: String, profile: Profile) throws {
    let usr = id.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty
      else {
        _log.report("unknown", level: .warning, event: .updating,
                    message: "invalid update attempt '\(id)'")
        throw Exception.fault("invalid login")
    }
    do {
      var u = try self._select(id)
      u.profile = profile
      try self._update(u)
    } catch Exception.fault(let message) {
      _log.report(id, level: .critical, event: .updating,
                  message: "unable to update '\(id)': \(message)")
      throw Exception.fault(message)
    }
    _log.report(id, level: .event, event: .updating, message: "profile updated")
  }

  /// perform a user login to generate and return a valid jwt token.
  /// Would log a login event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - password: the user password, will be automatically encoded by URL constraints
  ///   - subject: optional, subject to issue a jwt token, empty by default
  ///   - timeout: optional, jwt token valid period, in seconds. 3600 by default (one hour)
  ///   - headers: optional, extra headers to issue, empty by default.
  /// - returns: a valid jwt token
  public func login(id: String, password: String,
                     subject: String = "", timeout: Int = 3600,
                     headers: [String:Any] = [:]) throws -> String {
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
    password.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty, !pwd.isEmpty else {
        _log.report("unknown", level: .warning, event: .login,
                    message: "invalid login attempt '\(id)'/'\(password)'")
        throw Exception.fault("invalid login")
    }
    let u: U
    do {
      u = try _select(usr)
    } catch Exception.fault(let message) {
      _log.report(id, level: .warning, event: .login,
                  message: "unregistered user record")
      throw Exception.fault(message)
    }
    guard
      let decodedUsername = u.shadow.decrypt(_cipher, password: pwd, salt: u.salt),
      decodedUsername == usr
      else {
        _log.report(id, level: .warning, event: .login,
                    message: "access denied")
        throw Exception.fault("access denied")
    }
    let now = time(nil)
    let expiration = now + timeout
    let claims:[String: Any] = [
        "iss":_managerID, "sub": subject, "aud": id,
        "exp": expiration, "nbf": now, "iat": now, "jit": UUID().string
      ]

    guard let jwt = JWTCreator(payload: claims) else {
      _log.report(id, level: .critical, event: .login,
                  message: "token failure")
      throw Exception.fault("token failure")
    }

    let ret: String
    do {
      ret = try jwt.sign(alg: _alg, key: u.salt, headers: headers)
    } catch (let err) {
      _log.report(id, level: .critical, event: .login,
                  message: "jwt signature failure: \(err)")
      throw err
    }
    _log.report(id, level: .event, event: .login, message: "user logged")
    return ret
  }

  /// verify a jwt token. When a logged user is coming back to access a certain resource,
  /// use this function to verify the token he/she presents.
  /// Would log a verification event on an avaiable log filer.
  /// - parameters:
  ///   - id: the user id
  ///   - token: the JWT token that the user is presenting.
  ///   - renew: if true, the function will also return a new token.
  /// - throws: Exception.
  public func verify(id: String, token: String, renew: Bool = false) throws -> String? {
    guard let jwt = JWTVerifier(token) else {
      _log.report(id, level: .warning, event: .verification,
                  message: "jwt verification failure")
      throw Exception.fault("jwt verification failure")
    }
    let usr = id.stringByEncodingURL
    guard id.count.inRange(of: _sizeLimitOfCredential),
      !usr.isEmpty else {
        _log.report("unknown", level: .warning, event: .verification,
                    message: "invalid login verification: '\(id)'/'\(token)'")
        throw Exception.fault("invalid login verification")
    }
    let u: U
    do {
      u = try _select(usr)
    } catch Exception.fault(let message) {
      _log.report(id, level: .warning, event: .verification,
                  message: "unregistered user record")
      throw Exception.fault(message)
    }
    let now = time(nil)
    do {
      try jwt.verify(algo: _alg, key: HMACKey(u.salt))
    } catch {
      _log.report(id, level: .warning, event: .verification,
                  message: "jwt verification failure: \(token)")
      throw Exception.fault("jwt verification failure")
    }
    guard let iss = jwt.payload["iss"] as? String, iss == _managerID,
      let aud = jwt.payload["aud"] as? String, aud == id,
      let timeout = jwt.payload["exp"] as? Int, now <= timeout,
      let nbf = jwt.payload["nbf"] as? Int, nbf <= now else {
        _log.report(id, level: .warning, event: .verification,
                    message: "jwt invalid payload: \(jwt.payload)")
        throw Exception.fault("token failure")
    }
    _log.report(id, level: .event, event: .verification, message: "token verified")
    return nil
  }

  /// load a user profile by its id
  /// - parameter id: the user id
  /// - throws: Exception
  /// - returns: the user profile
  public func load(id: String) throws -> Profile {
    do {
      let p = try _select(id).profile
      _log.report(id, level: .event, event: .login, message: "retrieving user record")
      return p
    } catch Exception.fault(let message){
      let msg = "unable to load user record: \(message)"
      _log.report(id, level: .warning, event: .login,
                  message: msg)
      throw Exception.fault(msg)
    }
  }
  
  /// drop a user record by its id
  /// - parameter id: the user id
  /// - throws: Exception
  public func drop(id: String) throws {
    do {
      try _delete(id)
      _log.report(id, level: .event, event: .unregistration, message: "user closed")
    } catch Exception.fault(let message){
      let msg = "unable to remove user record: \(message)"
      _log.report(id, level: .warning, event: .unregistration,
                  message: msg)
      throw Exception.fault(msg)
    }
  }
}


