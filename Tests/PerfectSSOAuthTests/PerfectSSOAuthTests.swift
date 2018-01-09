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
import PerfectHTTP
import PerfectHTTPServer
import Dispatch

struct Profile: Codable, Equatable {
  static func ==(lhs: Profile, rhs: Profile) -> Bool {
    return lhs.firstName == rhs.firstName
      && lhs.lastName == rhs.lastName
      && lhs.age == rhs.age
      && lhs.email == rhs.email
  }

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
  let sqlite = "/tmp/user.db"
  let mysql_hst = "maria"
  let mysql_usr = "root"
  let mysql_pwd = "rockford"
  let mysql_dbt = "test"
  let pgsql_usr = "rocky"

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

  func request(url: String, method: String = "GET", headers:[String: String] = [:], fields: [String:String] = [:]) throws -> [String: Any] {
    guard let u = URL(string: url) else {
      throw Exception.fault("url malformed")
    }
    var req = URLRequest(url: u)
    for (k,v) in headers {
      req.setValue(v, forHTTPHeaderField: k)
    }
    req.httpMethod = method
    let post:[String] = fields.map { $0.key + "=" + $0.value.stringByEncodingURL }
    if post.count > 0 {
      req.httpBody = post.joined(separator: "&").data(using: .utf8)
    }
    let g = DispatchGroup()
    let session = URLSession(configuration: URLSessionConfiguration.default)
    var result = ""
    g.enter()
    let task = session.dataTask(with: req) { data, _, err in
      if let bytes: [UInt8] = (data?.map { $0 }) {
        result = String(validatingUTF8: bytes) ?? ""
      } else if let e = err {
        result = "\(e)"
      } else {
        result = "error"
      }
      g.leave()
    }
    task.resume()
    g.wait()
    return try result.jsonDecode() as? [String: Any] ?? [:]
  }

  func testHTTP(udb: UserDatabase, label: String) {
    print("preparing http test for \(label) ... +++++++++++++++++++++")
    let man = LoginManager<Profile>(udb: udb, log: log)
    let conf = HTTPAccessControl<Profile>.Configuration()
    let acs = HTTPAccessControl<Profile>(man, configuration: conf)
    let server = HTTPServer()
    server.serverPort = 8383
    let requestFilters: [(HTTPRequestFilter, HTTPFilterPriority)] = [(acs, HTTPFilterPriority.high)]
    server.setRequestFilters(requestFilters)
    var routes = Routes()
    routes.add(Route(method: .get, uri: "/**", handler: {
      request, response in
      response.setHeader(.contentType, value: "text/json")
      let ret: String
      do {
        ret = try response.request.scratchPad.jsonEncodedString()
      } catch {
        let e = "\(error)"
        ret = "{\"error\": \"json failure \(e.stringByEncodingURL)\"}"
      }
      response.setBody(string: ret)
      response.completed()
    }))
    server.addRoutes(routes)
    let q = DispatchQueue(label: "webhttp" + label)
    let g = DispatchGroup()
    g.enter()
    q.async {
      try! server.start()
      g.leave()
    }
    sleep(3)
    var jwt = ""
    do {
      var r = try request(url: "http://localhost:8383/")
      XCTAssertEqual(r["error"] as? String ?? "", "CSRF undefined")
      r = try request(url: "http://localhost:8383/", headers: ["origin":"localhost:8383"])
      XCTAssertEqual(r["error"] as? String ?? "", "request")
      let data = try JSONEncoder().encode(profile)
      let json = String(data: data, encoding: .utf8) ?? ""
      r = try request(url: "http://localhost:8383/api/reg",
                           method: "POST", headers: ["origin":"localhost:8383"],
                  fields: ["id":username, "password": godpass, "profile": json])
      jwt = r["jwt"] as? String ?? ""
      print("Bearer ", jwt)
      r = try request(url: "http://localhost:8383/",
                           headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"])
      XCTAssertEqual(r["id"] as? String ?? "", username)
      var p = r["profile"] as? String ?? ""
      print("profile", p)
      var prof = try! JSONDecoder().decode(Profile.self, from: p.data(using: .utf8)!)
      XCTAssertEqual(prof, profile)
      r = try request(url: "http://localhost:8383/api/login", method: "POST",
                      headers: ["origin": "localhost:8383"], fields: ["id": username, "password": godpass])
      jwt = r["jwt"] as? String ?? ""
      print("Bearer ", jwt)
      r = try request(url: "http://localhost:8383/some_where_else",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"])
      XCTAssertEqual(r["id"] as? String ?? "", username)
      p = r["profile"] as? String ?? ""
      print("profile", p)
      prof = try! JSONDecoder().decode(Profile.self, from: p.data(using: .utf8)!)
      XCTAssertEqual(prof, profile)
      r = try request(url: "http://localhost:8383/api/renew", method: "POST",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"])
      let jwt2 = r["jwt"] as? String ?? ""
      print("Bearer ", jwt)
      XCTAssertNotEqual(jwt, jwt2)
      r = try request(url: "http://localhost:8383/another_place",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt2)"])
      p = r["profile"] as? String ?? ""
      print("profile", p)
      prof = try! JSONDecoder().decode(Profile.self, from: p.data(using: .utf8)!)
      XCTAssertEqual(prof, profile)
      _ = try request(url: "http://localhost:8383/api/logout", method: "POST",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"])
    } catch {
      XCTFail("\(error)")
    }
    do {
      let r = try request(url: "http://localhost:8383/",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"])
      XCTAssertEqual(r["error"] as? String ?? "", "access")
    } catch {
      XCTFail("\(error)")
    }
    do {
      var r = try request(url: "http://localhost:8383/api/login", method: "POST",
                      headers: ["origin": "localhost:8383"], fields: ["id": username, "password": godpass])
      jwt = r["jwt"] as? String ?? ""
      r = try request(url: "http://localhost:8383/api/modpass", method: "POST",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt)"],
                      fields: ["password": badpass])
      XCTAssertEqual(r["error"] as? String ?? "", "")
      r = try request(url: "http://localhost:8383/api/login", method: "POST",
                          headers: ["origin": "localhost:8383"], fields: ["id": username, "password": badpass])
      let jwt2 = r["jwt"] as? String ?? ""
      XCTAssertNotEqual(jwt, jwt2)
      let rock = Profile(firstName: "rock", lastName: "way", age: 18, email: "rock@mail.com")
      let json = try JSONEncoder().encode(rock)
      r = try request(url: "http://localhost:8383/api/update", method: "POST",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt2)"],
                      fields: ["profile": String(data: json, encoding: .utf8) ?? ""])
      XCTAssertEqual(r["error"] as? String ?? "", "")
      r = try request(url: "http://localhost:8383/lost",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt2)"])
      let p = r["profile"] as? String ?? ""
      print("profile", p)
      let prof = try! JSONDecoder().decode(Profile.self, from: p.data(using: .utf8)!)
      XCTAssertEqual(prof, rock)
      r = try request(url: "http://localhost:8383/api/drop", method: "POST",
                      headers: ["origin":"localhost:8383", "Authorization": "Bearer \(jwt2)"])
      XCTAssertEqual(r["error"] as? String ?? "", "")
    } catch {
      XCTFail("\(error)")
    }
    server.stop()
    g.wait()
    print("http test for \(label) completed =======================")
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
              _ = try? manager.verify(token: t, logout: true)
            }
          }
        #else
          try? manager.register(id: u, password: p, profile: prof)
          if let t = try? manager.login(id: u, password: p) {
            _ = try? manager.verify(token: t, logout: true)
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
      XCTFail("\(error)")
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      _ = try manager.login(id: username, password: badpass)
    } catch Exception.access {
      print("expected access denied")
    } catch {
      XCTFail("\(error)")
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      let token = try manager.login(id: username, password: godpass)
      print(token)
      let x = try manager.verify(token: token)
      print(x.header)
      print(x.content)
      let tok2 = try manager.renew(id: username)
      XCTAssertNotEqual(tok2, token)
      let y = try manager.verify(token: tok2)
      XCTAssertEqual(x.content["iss"] as? String ?? "X", y.content["iss"] as? String ?? "Y")
    } catch {
      XCTFail("\(error)")
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log)
      try manager.update(id: username, password: badpass)
      _ = try manager.login(id: username, password: badpass)
    } catch {
      XCTFail("\(error)")
    }
    do {
      let manager = LoginManager<Profile>(udb: udb, log: log, recycle: 3)
      try manager.update(id: username, password: godpass)
      let token = try manager.login(id: username, password: godpass, timeout: 2)
      let x = try manager.verify(token: token)
      print(x.header)
      print(x.content)
      print("waiting for ticket expiration test")
      sleep(5)
      let y = try? manager.verify(token: token)
      XCTAssertNil(y)
      let token2 = try manager.login(id: username, password: godpass)
      let x2 = try manager.verify(token: token2, logout: true)
      print(x2.header)
      print(x2.content)
      let y2 = try? manager.verify(token: token2)
      XCTAssertNil(y2)
    } catch {
      XCTFail("\(error)")
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
    testLeak(udb: udb, label: label)
    testHTTP(udb: udb, label: label)
  }

  func testPostgreSQL() {
    let pg = PGConnection()
    _ = pg.connectdb(pgconnection)
    _ = pg.exec(statement: "DROP TABLE users")
    _ = pg.exec(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBPostgreSQL<Profile>(connection: pgconnection, sample: profile)
      testStandard(udb: udb, label: "postgresql")
    } catch {
      XCTFail("\(error)")
    }
  }
  func testMariaDB() {
    let mysql = MySQL()
    guard mysql.connect(host: mysql_hst, user: mysql_usr, password: mysql_pwd, db: mysql_dbt) else {
      XCTFail("connection failure")
      return
    }
    _ = mysql.query(statement: "DROP TABLE users")
    _ = mysql.query(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBMariaDB<Profile>(host: mysql_hst, user: mysql_usr,
       password: mysql_pwd, database: mysql_dbt, sample: profile)
      testStandard(udb: udb, label: "mariadb")
    } catch {
      XCTFail("\(error)")
    }
  }
  func testMySQL() {
    let mysql = MySQL()
    guard mysql.connect(host: mysql_hst, user: mysql_usr, password: mysql_pwd, db: mysql_dbt) else {
      XCTFail("connection failure")
      return
    }
    _ = mysql.query(statement: "DROP TABLE users")
    _ = mysql.query(statement: "DROP TABLE tickets")
    do {
      let udb = try UDBMySQL<Profile>(host: mysql_hst, user: mysql_usr,
      password: mysql_pwd, database: mysql_dbt, sample: profile)
      testStandard(udb: udb, label: "mysql")
    } catch {
      XCTFail("\(error)")
    }
  }
  func testSQLite() {
    unlink(sqlite)
    do {
      let udb = try UDBSQLite<Profile>(path: sqlite, sample: profile)
      testStandard(udb: udb, label: "sqlite")
    } catch {
      XCTFail("\(error)")
    }
  }
  func testJSONDir() {
    unlink("\(folder)/\(username).json")
    do {
      let udb = try UDBJSONFile<Profile>(directory: folder)
      testStandard(udb: udb, label: "jsonfile")
    } catch {
      XCTFail("\(error)")
    }
  }
}

