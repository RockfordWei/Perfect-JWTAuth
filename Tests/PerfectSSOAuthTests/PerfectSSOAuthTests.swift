import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile
import UDBSQLite
import UDBMySQL

class PerfectSSOAuthTests: XCTestCase {
  let username = "rocky@perfect.org"
  let godpass = "rockford"
  let badpass = "treefrog"
  let folder = "/tmp/users"
  let sqlite = "/tmp/users.db"
  let mysql_hst = "maria"
  let mysql_usr = "root"
  let mysql_pwd = "rockford"
  let mysql_dbt = "test"

  static var allTests = [
    ("testJSONDir", testJSONDir),
    ("testSQLite", testSQLite),
    ("testMySQL", testMySQL),
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
  }
  func testMySQL() {
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
  }
  func testSQLite() {
    do {
      let udb = try UDBSQLite(path: sqlite)
      let acm = AccessManager(udb: udb)
      try acm.register(username: username, password: godpass)
      _ = try acm.login(username: username, password: godpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite(path: sqlite)
      let acm = AccessManager(udb: udb)
      _ = try acm.login(username: username, password: badpass)
    } catch AccessManager.Exception.CryptoFailure {
      print("wrong password tested")
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBSQLite(path: sqlite)
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
      let udb = try UDBSQLite(path: sqlite)
      let acm = AccessManager(udb: udb)
      try acm.update(username: username, password: badpass)
      _ = try acm.login(username: username, password: badpass)
      try acm.drop(username: username)
    } catch {
      print("user deleted")
    }
  }
  func testJSONDir() {
    do {
      let udb = try UDBJSONFile(directory: folder)
      let acm = AccessManager(udb: udb)
      try acm.register(username: username, password: godpass)
      _ = try acm.login(username: username, password: godpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile(directory: folder)
      let acm = AccessManager(udb: udb)
      _ = try acm.login(username: username, password: badpass)
    } catch AccessManager.Exception.CryptoFailure {
      print("wrong password tested")
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try UDBJSONFile(directory: folder)
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
      let udb = try UDBJSONFile(directory: folder)
      let acm = AccessManager(udb: udb)
      try acm.update(username: username, password: badpass)
      _ = try acm.login(username: username, password: badpass)
      try acm.drop(username: username)
    } catch {
      print("user deleted")
    }
  }
}

