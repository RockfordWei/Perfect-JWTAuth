import Foundation
import PerfectLib
import PerfectThread
import PerfectMongoDB
import PerfectSSOAuth

typealias Exception = PerfectSSOAuth.Exception

public class UDBMongoDB<Profile> {

  internal let lock: Threading.Lock
  internal let db: MongoDatabase
  internal let client: MongoClient
  internal let users: MongoCollection
  public init(_ uri: String, database: String, document: String) throws {
    lock = Threading.Lock()
    client = try MongoClient(uri: uri)
    let status = client.serverStatus()
    switch status {
    case .error(let domain, let code, let message):
      throw Exception.Fault("\(domain) \(code) \(message)")
    case .replyDoc(_):
      break
    default:
      throw Exception.Fault("unknow status: \(status)")
    }
    db = client.getDatabase(name: database)
    guard db.name() == database else {
      throw Exception.Fault("unexpected database name: '\(db.name())' != '\(database)'")
    }
    _ = db.createCollection(name: document, options: nil)
    guard let collection = db.getCollection(name: document) else {
      throw Exception.Fault("document table \(document) is not ready")
    }
    users = collection
  }

  deinit {
    db.close()
    client.close()
  }

  public func insert<Profile>(_ record: UserRecord<Profile>) throws {

  }
}
