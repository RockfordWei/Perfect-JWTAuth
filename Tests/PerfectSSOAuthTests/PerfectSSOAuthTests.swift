import XCTest
@testable import PerfectSSOAuth
import PerfectCrypto
import Foundation

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
      let udb = try EmbeddedUDB(directory: folder)
      let acm = AccessManager(udb: udb)
      try acm.save(username: username, password: godpass)
      _ = try acm.verify(username: username, password: godpass)
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try EmbeddedUDB(directory: folder)
      let acm = AccessManager(udb: udb)
      _ = try acm.verify(username: username, password: badpass)
    } catch AccessManager.Exception.CryptoFailure {
      print("wrong password tested")
    } catch {
      XCTFail(error.localizedDescription)
    }
    do {
      let udb = try EmbeddedUDB(directory: folder)
      let acm = AccessManager(udb: udb)
      try udb.drop(username: username)
      _ = try acm.verify(username: username, password: godpass)
    } catch {
      print("user deleted")
    }
    do {
      let udb = try EmbeddedUDB(directory: folder)
      let acm = AccessManager(udb: udb)
      try acm.save(username: username, password: godpass)
      let token = try acm.verify(username: username, password: godpass)
      print(token)
      sleep(3)
      print("wait for verification")
      try acm.verify(username: username, token: token)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
}

