import Foundation
import RealmSwift


var dummyURL: URL {
    return Bundle(for: AppDelegate.self)
        .url(forResource: "dummy",
             withExtension: "realm")!
}
