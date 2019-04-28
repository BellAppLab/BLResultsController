import AppKit
import RealmSwift


func makeDummyRealm() {
    let baseURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("BLResultsController")
    if !FileManager.default.fileExists(atPath: baseURL.path) {
        do {
            try FileManager.default.createDirectory(at: baseURL,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        } catch {
            fatalError("\(error)")
        }
    }

    let url = baseURL.appendingPathComponent("dummy.realm")
    Realm.Configuration.defaultConfiguration.fileURL = url
    let realm: Realm
    do {
        realm = try Realm()
    } catch {
        fatalError("\(error)")
    }

    var todos = [Todo]()

    Priority.sortedCases.forEach { priority in
        todos.append(contentsOf: priority.makeAllTodos())
    }

    do {
        try realm.write {
            todos.forEach { realm.add($0) }
        }
    } catch {
        fatalError("\(error)")
    }

    #if swift(>=4.2)
    NSWorkspace.shared.open(baseURL)
    #else
    NSWorkspace.shared().open(baseURL)
    #endif

    exit(1)
}
