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

  /// the user is trying to renew the current jwt token
  case renewal = 6

  /// there is a system event
  case system = 7
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

  /// insert a new ticket with its expiration setting to the database
  /// - parameter ticket: the ticket to save
  /// - parameter expiration: the expiration end in timestamp
  /// - throws: Exception
  func issue(_ ticket: String, _ expiration: time_t) throws

  /// invalidate a ticket
  /// - parameter ticket: the ticket to cancel
  /// - throws: Exception
  func cancel(_ ticket: String) throws

  /// test if the giving ticket is valid
  /// - parameter ticket: the ticket to check
  func isValid(_ ticket: String) -> Bool
}

/// a protocol that monitors unusual user behaviours, such as excessive access, etc.
/// login manager will try these callbacks prior to the actual operations
public protocol RateLimiter {
  /// an attempt on registration, should throw errors if overrated.
  /// - parameter userId: the user id used to attampt registration
  /// - parameter password: the user password used to attampt registration
  func onAttemptRegister(_ userId: String, password: String) throws

  /// an attempt on login, should throw errors if overrated.
  /// - parameter userId: the user id used to attampt login
  /// - parameter password: the user password used to attampt login
  func onAttemptLogin(_ userId: String, password: String) throws

  /// a Login event, should throw errors if overrated.
  /// - parameter record: the user record to login
  func onLogin<Profile>(_ record: UserRecord<Profile>) throws

  /// an attempt on token verification, should throw errors if overrated.
  /// - parameter userId: the user id used to attampt verification
  /// - parameter token: the token used to attampt verification
  func onAttemptToken(_ userID: String, token: String) throws

  /// a token renew event, should throw errors if overrated.
  /// - parameter record: the user record to renew token
  func onRenewToken<Profile>(_ record: UserRecord<Profile>) throws

  /// a user profile update event, should throw errors if overrated.
  /// - parameter record: the user record to update
  func onUpdate<Profile>(_ record: UserRecord<Profile>) throws

  /// an update on password, should throw errors if overrated.
  /// - parameter userId: the user id used to update password
  /// - parameter password: the user password used to update
  func onUpdate(_ userId: String, password: String) throws

  /// an attempt on deletion user record, should throw errors if overrated.
  /// - parameter userId: the user id used to delete record
  func onDeletion(_ userId: String) throws
}

public final class Unlimitated<Profile> : RateLimiter {
  public func onAttemptRegister(_ userId: String, password: String) throws {}
  public func onAttemptLogin(_ userId: String, password: String) throws { }
  public func onLogin<Profile>(_ record: UserRecord<Profile>) throws { }
  public func onAttemptToken(_ userID: String, token: String) throws { }
  public func onRenewToken<Profile>(_ record: UserRecord<Profile>) throws { }
  public func onUpdate<Profile>(_ record: UserRecord<Profile>) throws { }
  public func onUpdate(_ userId: String, password: String) throws { }
  public func onDeletion(_ userId: String) throws { }
}

/// Username / Password Quality Control Protocol
/// Login mananger will try these callbacks on certain event.
public protocol LoginQualityControl {

  /// if the username is good enough, should yield error if not.
  /// - parameter userId: the username to register or login
  func goodEnough(userId: String) throws

  /// if the password is strong enough, should yield error if not.
  /// - parameter password: the password to register or update.
  func goodEnough(password: String) throws
}

/// default login control - just test the username / password in length
public final class HumblestLoginControl: LoginQualityControl {

  internal let size: CountableClosedRange<Int>

  /// constructor
  /// - parameter sizeLimit: a closed range of username / password length
  public init(_ sizeLimit: CountableClosedRange<Int> = 5...80) {
    size = sizeLimit
  }
  public func goodEnough(userId: String) throws {
    guard userId.count.inRange(of: size) else {
      throw Exception.fault("invalid username")
    }
  }
  public func goodEnough(password: String) throws {
    guard password.count.inRange(of: size) else {
      throw Exception.fault("invalid password")
    }
  }
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
  internal let _managerID: String
  internal let _alg: JWT.Alg
  internal let _log: LogManager
  internal let _rate: RateLimiter
  internal let _pass: LoginQualityControl

  typealias U = UserRecord<Profile>
  internal let _insert: (_ record: U ) throws -> Void
  internal let _select: (_ id: String) throws -> U
  internal let _update: (_ record: U) throws -> Void
  internal let _delete: (_ id: String) throws -> Void
  internal let _issue: (_ ticket: String, _ expiration: time_t) throws -> Void
  internal let _cancel: (_ ticket: String) throws -> Void
  internal let _isValid: (_ ticket: String) -> Bool
  /// every instance of LoginManager has a unique manager id, in form of uuid
  public var globalId: String { return _managerID }

  /// constructor of a Login Manager
  /// - parameters:
  ///   - cipher: a cipher algorithm to do the password encryption. AES_252_CBC by default.
  ///   - keyIterations: key iteration times for encryption, 1024 by default.
  ///   - digest: digest algorithm for encryption, MD5 by default.
  ///   - saltLength: length to generate the salt string, 16 by default.
  ///   - alg: JWT token generation algorithm, HS256 by default
  ///   - udb: a user database to attach
  ///   - log: a log manager if applicable, default nil for logging to the console.
  ///   - rate: a RateLimiter. Any user operations, such as access, update or token renew, will call the rate limiter first. By default it is unlimited
  ///   - pass: a login / password quality control, will call before any password updates. No password quality control by default.
  ///   - recycle: the waiting period to recycle the expired tickets, in seconds. If 0 or skipped, it will be set to 60 seconds by default
  public init(cipher: Cipher = .aes_256_cbc, keyIterations: Int = 1024,
              digest: Digest = .md5, saltLength: Int = 16,
              alg: JWT.Alg = .hs256,
              udb: UserDatabase,
              log: LogManager? = nil,
              rate: RateLimiter? = nil,
              pass: LoginQualityControl? = nil,
              recycle: Int = 0) {
    _cipher = cipher
    _keyIterations = keyIterations
    _digest = digest
    _saltLength = saltLength
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
    _issue = udb.issue
    _cancel = udb.cancel
    _isValid = udb.isValid
    if let limiter = rate {
      _rate = limiter
    } else {
      _rate = Unlimitated<Profile>()
    }
    if let pqc = pass {
      _pass = pqc
    } else {
      _pass = HumblestLoginControl()
    }
    DataworkUtility.recyclingSpan = recycle > 0 ? recycle: 60
  }

  /// register a new user record. Would log a register event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - password: the user password, will be automatically encoded by URL constraints
  ///   - profile: the user profile to attach
  /// - throws: Exception
  public func register(id: String, password: String, profile: Profile) throws {
    do {
      try _rate.onAttemptRegister(id, password: password)
      try _pass.goodEnough(userId: id)
      try _pass.goodEnough(password: password)
    } catch (let err) {
      _log.report(id, level: .warning, event: .registration, message: err.localizedDescription)
      throw err
    }
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
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
    } catch (let err) {
      _log.report(id, level: .warning, event: .registration, message: err.localizedDescription)
      throw err
    }
    _log.report(id, level: .event, event: .registration, message: "user registered")
  }

  /// update a user's password. Would log an updating password event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - password: the user's new password, will be automatically encoded by URL constraints
  /// - throws: Exception
  public func update(id: String, password: String) throws {
    do {
      try _rate.onUpdate(id, password: password)
      try _pass.goodEnough(userId: id)
      try _pass.goodEnough(password: password)
    } catch (let err) {
      _log.report(id, level: .warning, event: .updating, message: err.localizedDescription)
      throw err
    }
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    guard let random = ([UInt8](randomCount: _saltLength)).encode(.hex),
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
    } catch (let err) {
      _log.report(id, level: .warning, event: .updating, message: err.localizedDescription)
      throw err
    }
    _log.report(id, level: .event, event: .updating, message: "password updated")
  }

  /// update a user's profile. Would log an updating profile event on an available log filer.
  /// - parameters:
  ///   - id: the user id, will be automatically encoded by URL constraints
  ///   - profile: the user's new profile
  /// - throws: Exception
  public func update(id: String, profile: Profile) throws {
    do {
      try _pass.goodEnough(userId: id)
    } catch (let err) {
      _log.report(id, level: .warning, event: .updating, message: err.localizedDescription)
      throw err
    }
    let usr = id.stringByEncodingURL
    do {
      var u = try self._select(usr)
      try _rate.onUpdate(u)
      u.profile = profile
      try self._update(u)
    } catch (let err) {
      _log.report(id, level: .warning, event: .updating, message: err.localizedDescription)
      throw err
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
    do {
      try _pass.goodEnough(userId: id)
      try _pass.goodEnough(password: password)
      try _rate.onAttemptLogin(id, password: password)
    } catch (let err) {
      _log.report(id, level: .warning, event: .login, message: err.localizedDescription)
      throw err
    }
    let usr = id.stringByEncodingURL
    let pwd = password.stringByEncodingURL
    let u: U
    do {
      u = try _select(usr)
      try _rate.onLogin(u)
    } catch (let err) {
      _log.report(id, level: .warning, event: .login, message: err.localizedDescription)
      throw err
    }
    guard
      let decodedUsername = u.shadow.decrypt(_cipher, password: pwd, salt: u.salt),
      decodedUsername == usr
      else {
        _log.report(id, level: .warning, event: .login,
                    message: "access denied")
        throw Exception.fault("access denied")
    }
    return try self.renew(u: u, subject: subject, timeout: timeout, headers: headers)
  }

  /// verify a jwt token. When a logged user is coming back to access a certain resource,
  /// use this function to verify the token he/she presents.
  /// Would log a verification event on an avaiable log filer.
  /// - parameters:
  ///   - id: the user id
  ///   - token: the JWT token that the user is presenting.
  ///   - allowSSO: allow an incoming foreign token, i.e, the token is not issue by this login manager.
  ///   - logout: log off the current token bearer. **NOTE** this operation can only perform on local issued tickets.
  /// - returns: a tuple of header & content info encoded in the token.
  /// - throws: Exception.
  public func verify(id: String, token: String, allowSSO: Bool = true, logout: Bool = false) throws ->
    (header: [String: Any], content: [String: Any]) {
    do {
      try _pass.goodEnough(userId: id)
      try _rate.onAttemptToken(id, token: token)
    } catch (let err) {
      _log.report(id, level: .warning, event: .verification, message: err.localizedDescription)
      throw err
    }
    guard let jwt = JWTVerifier(token) else {
      _log.report(id, level: .warning, event: .verification,
                  message: "jwt verification failure")
      throw Exception.fault("jwt verification failure")
    }
    let usr = id.stringByEncodingURL
    let u: U
    do {
      u = try _select(usr)
    } catch (let err) {
      _log.report(id, level: .warning, event: .verification, message: err.localizedDescription)
      throw err
    }
    let now = time(nil)
    do {
      try jwt.verify(algo: _alg, key: HMACKey(u.salt))
    } catch {
      _log.report(id, level: .warning, event: .verification,
                  message: "jwt verification failure: \(token)")
      throw Exception.fault("jwt verification failure")
    }
    guard let iss = jwt.payload["iss"] as? String else {
      throw Exception.fault("issuer is null")
    }
    if iss != _managerID {
      guard allowSSO else {
        throw Exception.fault("invalid issuer")
      }
    }
    guard let aud = jwt.payload["aud"] as? String,
      aud == id,
      let timeout = jwt.payload["exp"] as? Int,
      now <= timeout,
      let nbf = jwt.payload["nbf"] as? Int,
      nbf <= now,
      let ticket = jwt.payload["jit"] as? String
      else {
        _log.report(id, level: .warning, event: .verification,
                    message: "jwt invalid payload: \(jwt.payload)")
        throw Exception.fault("token failure")
    }

    var needlog = true
    if iss == _managerID {
      if logout {
        do {
          try _cancel(ticket)
          _log.report(id, level: .event, event: .logoff, message: nil )
        } catch (let err) {
          _log.report(id, level: .warning, event: .logoff,
                      message: "log out failure:" + err.localizedDescription )
        }
        needlog = false
      } else {
        guard _isValid(ticket) else {
          _log.report(id, level: .warning, event: .verification,
                      message: "jwt valid but ticket is either expired or cancelled")
          throw Exception.fault("invalid ticket")
        }
      }
    }

    if needlog {
      _log.report(id, level: .event, event: .verification, message: "token verified")
    }
    return (header: jwt.header, content: jwt.payload)
  }

  internal func renew(u: U,
                      subject: String = "", timeout: Int = 3600,
                      headers: [String:Any] = [:]) throws -> String {
    let now = time(nil)
    let expiration = now + timeout
    let ticket =  UUID().string
    let claims:[String: Any] = [
      "iss":_managerID, "sub": subject, "aud": u.id,
      "exp": expiration, "nbf": now, "iat": now, "jit": ticket
    ]

    try _issue(ticket, expiration)

    guard let jwt = JWTCreator(payload: claims) else {
      _log.report(u.id, level: .critical, event: .login,
                  message: "token failure")
      throw Exception.fault("token failure")
    }

    let ret: String
    do {
      ret = try jwt.sign(alg: _alg, key: u.salt, headers: headers)
    } catch (let err) {
      _log.report(u.id, level: .critical, event: .login,
                  message: "jwt signature failure: \(err)")
      throw err
    }
    _log.report(u.id, level: .event, event: .login, message: "user logged")
    return ret
  }

  /// generate a jwt token. When a logged user is coming back to access a certain resource,
  /// use this function to alloc a token to the user
  /// - parameters:
  ///   - id: the user id
  ///   - subject: optional, subject to issue a jwt token, empty by default
  ///   - timeout: optional, jwt token valid period, in seconds. 3600 by default (one hour)
  ///   - headers: optional, extra headers to issue, empty by default.
  /// - throws: Exception
  /// - returns: a valid jwt token
  public func renew(id: String,
                    subject: String = "", timeout: Int = 3600,
                    headers: [String:Any] = [:]) throws -> String {
    do {
      try _pass.goodEnough(userId: id)
    } catch (let err) {
      _log.report(id, level: .warning, event: .renewal, message: err.localizedDescription)
      throw err
    }
    let u: U
    do {
      u = try _select(id)
      try _rate.onRenewToken(u)
    } catch (let err) {
      _log.report(id, level: .warning, event: .renewal, message: err.localizedDescription)
      throw err
    }
    return try self.renew(u: u, subject: subject, timeout: timeout, headers: headers)
  }

  /// load a user profile by its id
  /// - parameter id: the user id
  /// - throws: Exception
  /// - returns: the user profile
  public func load(id: String) throws -> Profile {
    return try _select(id).profile
  }
  
  /// drop a user record by its id
  /// - parameter id: the user id
  /// - throws: Exception
  public func drop(id: String) throws {
    do {
      try _pass.goodEnough(userId: id)
      try _rate.onDeletion(id)
      try _delete(id)
      _log.report(id, level: .event, event: .unregistration, message: "user closed")
    } catch (let err) {
      _log.report(id, level: .warning, event: .unregistration, message: err.localizedDescription)
      throw err
    }
  }
}


