import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile
import UDBSQLite
import UDBMySQL
import UDBMariaDB
import UDBPostgreSQL
import PerfectMySQL
import PerfectPostgreSQL
import PerfectLib
import Dispatch

struct Profile: Codable {
  public var firstName = ""
  public var lastName = ""
  public var age = 0
  public var email = ""
}

class PerfectSSOAuthTests: XCTestCase {
  let username = "rockywei"
  let godpass = "rockford"
  let badpass = "treefrog"
  let folder = "/tmp"
  let sqlite = "/tmp/users.db"
  let mysql_hst = "maria"
  let mysql_usr = "root"
  let mysql_pwd = "rockford"
  let mysql_dbt = "test"
  let pgsql_usr = "rocky"
  let table = "users"
  let profile = Profile(firstName: "rocky", lastName: "wei", age: 21, email: "rocky@perfect.org")
  let log = FileLogger("/tmp", GMT: false)
  let pgconnection = "postgresql://rocky:rockford@maria/test"

  var users: [String: String] = [:]
  var expects = [XCTestExpectation]()

  let randomSize = 1024
  static var allTests = [
    ("testJSONDir", testJSONDir),
    ("testSQLite", testSQLite),
    ("testMySQL", testMySQL),
    ("testMariaDB", testMariaDB),
    ("testPostgreSQL", testPostgreSQL),
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
    for _ in 0..<self.randomSize {
      guard
        let ux = ([UInt8](randomCount: 8)).encode(.hex),
        let px = ([UInt8](randomCount: 8)).encode(.hex),
        let u = String(validatingUTF8: ux),
        let p = String(validatingUTF8: px)
      else {
          XCTFail("random table creation failed")
          break
      }
      users[u] = p
    }
    expects.removeAll(keepingCapacity: false)
  }

  func testLeak(udb: UserDatabase, label: String) {
    print("preparing memory leaking test for \(label) ... may take minutes")
    let now = time(nil)
    let manager = LoginManager<Profile>(udb: udb, log: log)
    let prof = profile
    let q = DispatchQueue(label: label)
    let g = DispatchGroup()

    for (u,p) in users {
      g.enter()
      q.async {
        // if you found memory usage growth, use autoreleasepool to cease it.
        // it is a fake leak so don't worry about it!
        #if os(OSX)
          autoreleasepool {
            try? manager.register(id: u, password: p, profile: prof)
            if let t = try? manager.login(id: u, password: p) {
              _ = try? manager.verify(id: u, token: t, logout: true)
            }
          }
        #else
          try? manager.register(id: u, password: p, profile: prof)
          if let t = try? manager.login(id: u, password: p) {
            _ = try? manager.verify(id: u, token: t, logout: true)
          }
        #endif
        g.leave()
      }
    }
    g.wait()
    let duration = time(nil) - now
    print("------------ long test of \(label): \(duration) seconds for \(self.randomSize) access")
    self.log.report("system", level: .event, event: .system, message: "\(label) tested")
  }

  func testStandard(udb: UserDatabase, label: String) {
    log.report("system", level: .event, event: .system, message: "testing \(label)")
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      try manager.register(id: username, password: godpass, profile: profile)
      _ = try manager.login(id: username, password: godpass)
      let rocky = try manager.load(id: username)
      print(rocky)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      _ = try manager.login(id: username, password: badpass)
    } catch Exception.fault(let reason) {
      print("expected error:", reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      let token = try manager.login(id: username, password: godpass)
      print(token)
      let x = try manager.verify(id: username, token: token)
      print(x.header)
      print(x.content)
      let tok2 = try manager.renew(id: username)
      XCTAssertNotEqual(tok2, token)
      let y = try manager.verify(id: username, token: tok2)
      XCTAssertEqual(x.content["iss"] as? String ?? "X", y.content["iss"] as? String ?? "Y")
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      try manager.update(id: username, password: badpass)
      _ = try manager.login(id: username, password: badpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log, recycle: 3)
      try manager.update(id: username, password: godpass)
      let token = try manager.login(id: username, password: godpass, timeout: 2)
      let x = try manager.verify(id: username, token: token)
      print(x.header)
      print(x.content)
      print("waiting for ticket expiration test")
      sleep(5)
      let y = try? manager.verify(id: username, token: token)
      XCTAssertNil(y)
      let token2 = try manager.login(id: username, password: godpass)
      let x2 = try manager.verify(id: username, token: token2, logout: true)
      print(x2.header)
      print(x2.content)
      let y2 = try? manager.verify(id: username, token: token2)
      XCTAssertNil(y2)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      var rocky = try manager.load(id: username)
      print(rocky)
      rocky.email = "rockywei@gmx.com"
      try manager.update(id: username, profile: rocky)
      let r = try manager.load(id: username)
      XCTAssertEqual(rocky.email, r.email)
      try manager.drop(id: username)
    } catch {
      XCTFail("user deleted")
    }
  }

  func testPostgreSQL() {
    let pg = PGConnection()
    _ = pg.connectdb(pgconnection)
    _ = pg.exec(statement: "DROP TABLE \(table)")
    _ = pg.exec(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBPostgreSQL<Profile>(connection: pgconnection, sample: profile)
      testStandard(udb: udb, label: "postgresql")
      testLeak(udb: udb, label: "postgresql")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testMariaDB() {
    let mysql = MySQL()
    guard mysql.connect(host: mysql_hst, user: mysql_usr, password: mysql_pwd, db: mysql_dbt) else {
      XCTFail("connection failure")
      return
    }
    _ = mysql.query(statement: "DROP TABLE \(table)")
    _ = mysql.query(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
       password: mysql_pwd, database: mysql_dbt, sample: profile)
      testStandard(udb: udb, label: "mariadb")
      testLeak(udb: udb, label: "mariadb")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testMySQL() {
    let mysql = MySQL()
    guard mysql.connect(host: mysql_hst, user: mysql_usr, password: mysql_pwd, db: mysql_dbt) else {
      XCTFail("connection failure")
      return
    }
    _ = mysql.query(statement: "DROP TABLE \(table)")
    _ = mysql.query(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
      password: mysql_pwd, database: mysql_dbt, sample: profile)
      testStandard(udb: udb, label: "mysql")
      testLeak(udb: udb, label: "mysql")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testSQLite() {
    unlink(sqlite)
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, sample: profile)
      testStandard(udb: udb, label: "sqlite")
      testLeak(udb: udb, label: "sqlite")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testJSONDir() {
    unlink("\(folder)/\(username).json")
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      testStandard(udb: udb, label: "jsonfile")
      testLeak(udb: udb, label: "jsonfile")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
}

