import Foundation
import RealmSwift


var dummyURL: URL {
    return Bundle(for: BLResultsControllerSetup_Tests.self)
        .url(forResource: "dummy",
             withExtension: "realm")!
}


func dummyURLCopy(with testName: String) -> URL {
    return Realm.Configuration
        .defaultConfiguration
        .fileURL!
        .deletingLastPathComponent()
        .appendingPathComponent("dummy_copy_\(testName).realm")
}


func realmCopy(with testName: String) -> Realm {
    return try! Realm(fileURL: dummyURLCopy(with: testName))
}
