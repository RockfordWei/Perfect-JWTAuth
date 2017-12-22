import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile
import UDBSQLite
import UDBMySQL
import UDBMariaDB
import PerfectMySQL

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
  let table = "users"
  let profile = Profile(firstName: "rocky", lastName: "wei", age: 21, email: "rocky@perfect.org")
  static var allTests = [
    ("testJSONDir", testJSONDir),
    ("testSQLite", testSQLite),
    ("testMySQL", testMySQL),
    ("testMariaDB", testMariaDB),
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
    unlink(sqlite)
    let mysql = MySQL()
    guard mysql.setOption(.MYSQL_SET_CHARSET_NAME, "utf8mb4"),
      mysql.connect(host: mysql_hst, user: mysql_usr, password: mysql_pwd, db: mysql_dbt) else {
        XCTFail("connection failure")
        return
    }
    _ = mysql.query(statement: "DROP TABLE \(table)")
  }
  func testMariaDB() {
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
       password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.register(id: username, password: godpass, profile: profile)
      _ = try acm.login(id: username, password: godpass)
      let rocky = try acm.load(id: username)
      print(rocky)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      _ = try acm.login(id: username, password: badpass)
    } catch Exception.Fault(let reason) {
      print(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      let token = try acm.login(id: username, password: godpass)
      print(token)
      sleep(1)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
                                        password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.update(id: username, password: badpass)
      _ = try acm.login(id: username, password: badpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
                                        password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      var rocky = try acm.load(id: username)
      print(rocky)
      rocky.email = "rockywei@gmx.com"
      try acm.update(id: username, profile: rocky)
      let r = try acm.load(id: username)
      XCTAssertEqual(rocky.email, r.email)
      try acm.drop(id: username)
    } catch {
      print("user deleted")
    }
  }
  func testMySQL() {
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.register(id: username, password: godpass, profile: profile)
      _ = try acm.login(id: username, password: godpass)
      let rocky = try acm.load(id: username)
      print(rocky)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      _ = try acm.login(id: username, password: badpass)
    } catch Exception.Fault(let reason) {
      print(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      let token = try acm.login(id: username, password: godpass)
      print(token)
      sleep(1)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.update(id: username, password: badpass)
      _ = try acm.login(id: username, password: badpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
                                      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      var rocky = try acm.load(id: username)
      print(rocky)
      rocky.email = "rockywei@gmx.com"
      try acm.update(id: username, profile: rocky)
      let r = try acm.load(id: username)
      XCTAssertEqual(rocky.email, r.email)
      try acm.drop(id: username)
    } catch {
      print("user deleted")
    }
  }
  func testSQLite() {
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.register(id: username, password: godpass, profile: profile)
      _ = try acm.login(id: username, password: godpass)
      let rocky = try acm.load(id: username)
      print(rocky)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      _ = try acm.login(id: username, password: badpass)
    } catch Exception.Fault(let reason) {
      print(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      let token = try acm.login(id: username, password: godpass)
      print(token)
      sleep(1)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.update(id: username, password: badpass)
      _ = try acm.login(id: username, password: badpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      var rocky = try acm.load(id: username)
      print(rocky)
      rocky.email = "rockywei@gmx.com"
      try acm.update(id: username, profile: rocky)
      let r = try acm.load(id: username)
      XCTAssertEqual(rocky.email, r.email)
      try acm.drop(id: username)
    } catch {
      print("user deleted")
    }
  }
  func testJSONDir() {
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.register(id: username, password: godpass, profile: profile)
      _ = try acm.login(id: username, password: godpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      _ = try acm.login(id: username, password: badpass)
    } catch Exception.Fault(let reason) {
      print(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      let token = try acm.login(id: username, password: godpass)
      print(token)
      sleep(1)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.update(id: username, password: badpass)
      _ = try acm.login(id: username, password: badpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      var rocky = try acm.load(id: username)
      print(rocky)
      rocky.email = "rockywei@gmx.com"
      try acm.update(id: username, profile: rocky)
      let r = try acm.load(id: username)
      XCTAssertEqual(rocky.email, r.email)
      try acm.drop(id: username)
    } catch {
      print("user deleted")
    }
  }
}

