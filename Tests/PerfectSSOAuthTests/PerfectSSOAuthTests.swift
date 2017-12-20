import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation
import UDBJSONFile

class PerfectSSOAuthTests: XCTestCase {
  static var allTests = [
    ("testJSONDir", testJSONDir),
    ]

  override func setUp() {
    _ = PerfectCrypto.isInitialized
  }
  func testJSONDir() {
    let username = "rocky@perfect.org"
    let godpass = "rockford"
    let badpass = "treefrog"
    let folder = "/tmp/users"
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

