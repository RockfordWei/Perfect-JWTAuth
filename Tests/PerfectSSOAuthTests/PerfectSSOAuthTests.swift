import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile
import UDBSQLite
import UDBMySQL

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
  let folder = "/tmp/users"
  let sqlite = "/tmp/users.db"
  let mysql_hst = "maria"
  let mysql_usr = "root"
  let mysql_pwd = "rockford"
  let mysql_dbt = "test"
  let profile = Profile(firstName: "rocky", lastName: "wei", age: 21, email: "rocky@perfect.org")
  static var allTests = [
    ("testJSONDir", testJSONDir),
    ("testSQLite", testSQLite),
    ("testMySQL", testMySQL),
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
  }
  func testMySQL() {
    /*
    do {
      let udb = try UDBMySQL(host: mysql_hst, user: mysql_usr, password: mysql_pwd, database: mysql_dbt)
      let acm = AccessManager(udb: udb)
      try acm.register(username: username, password: godpass)
      _ = try acm.login(username: username, password: godpass)
    } catch AccessManager.Exception.Reasonable(let reason) {
      XCTFail(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL(host: mysql_hst, user: mysql_usr, password: mysql_pwd, database: mysql_dbt)
      let acm = AccessManager(udb: udb)
      _ = try acm.login(username: username, password: badpass)
    } catch AccessManager.Exception.CryptoFailure {
      print("wrong password tested")
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL(host: mysql_hst, user: mysql_usr, password: mysql_pwd, database: mysql_dbt)
      let acm = AccessManager(udb: udb)
      let token = try acm.login(username: username, password: godpass)
      print(token)
      sleep(3)
      print("wait for verification")
      try acm.verify(username: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBMySQL(host: mysql_hst, user: mysql_usr, password: mysql_pwd, database: mysql_dbt)
      let acm = AccessManager(udb: udb)
      try acm.update(username: username, password: badpass)
      _ = try acm.login(username: username, password: badpass)
      try acm.drop(username: username)
    } catch {
      print("user deleted")
    }
*/
  }
  func testSQLite() {
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: "users", sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.register(id: username, password: godpass, profile: profile)
      _ = try acm.login(id: username, password: godpass)
      let rocky = try acm.load(id: username)
      print(rocky.profile)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: "users", sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      _ = try acm.login(id: username, password: badpass)
    } catch Exception.Fault(let reason) {
      print(reason)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: "users", sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      let token = try acm.login(id: username, password: godpass)
      print(token)
      sleep(3)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, table: "users", sample: profile)
      let acm = AccessManager<Profile>(udb: udb)
      try acm.update(id: username, password: badpass, profile: profile)
      _ = try acm.login(id: username, password: badpass)
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
      sleep(2)
      print("wait for verification")
      try acm.verify(id: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      let acm = AccessManager<Profile>(udb: udb)
      let rocky: UserRecord<Profile> = try acm.load(id: username)
      print(rocky.profile)
      try acm.update(id: username, password: badpass, profile: profile)
      _ = try acm.login(id: username, password: badpass)
      try acm.drop(id: username)
    } catch {
      print("user deleted")
    }
  }
}

