import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile
import UDBSQLite
import UDBMySQL
import UDBMariaDB
import UDBPostgreSQL
import UDBMongoDB
import PerfectMySQL
import PerfectPostgreSQL
import PerfectMongoDB

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

  static var allTests = [
    ("testJSONDir", testJSONDir),
    ("testSQLite", testSQLite),
    ("testMySQL", testMySQL),
    ("testMariaDB", testMariaDB),
    ("testPostgreSQL", testPostgreSQL),
    ("testMongoDB", testMongoDB)
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
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
      try manager.verify(id: username, token: token)
      let tok2 = try manager.renew(id: username)
      XCTAssertNotEqual(tok2, token)
      try manager.verify(id: username, token: tok2)
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
    log.report("system", level: .event, event: .system, message: "\(label) tested")
  }

  func testMongoDB() {
    do {
      _ = try UDBMongoDB<Profile>("mongodb://maria", database: "test", document: "users")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testPostgreSQL() {
    let pg = PGConnection()
    _ = pg.connectdb(pgconnection)
    _ = pg.exec(statement: "DROP TABLE \(table)")
    do {
      let udb = try UDBPostgreSQL<Profile>(connection: pgconnection, table: "users", sample: profile)
      testStandard(udb: udb, label: "postgresql")
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
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
       password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      testStandard(udb: udb, label: "mariadb")
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
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
      password: mysql_pwd, database: mysql_dbt, table: table, sample: profile)
      testStandard(udb: udb, label: "mysql")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testSQLite() {
    unlink(sqlite)
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: table, sample: profile)
      testStandard(udb: udb, label: "sqlite")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  func testJSONDir() {
    unlink("\(folder)/\(username).json")
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      testStandard(udb: udb, label: "jsonfile")
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
}

