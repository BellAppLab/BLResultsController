import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerBaseTest: XCTestCase
{
    private static func copyDummyRealmTo(url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: dummyURL,
                                             to: url)
        } catch {
            XCTFail("\(error)")
            abort()
        }
    }

    private static func deleteDummyRealmAt(url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            XCTFail("\(error)")
            abort()
        }
    }

    private static var controllers: [String: ResultsController<Int, Todo>] = [:]

    override class func tearDown() {
        controllers = [:]
    }

    final func makeRealm(function: String = #function) -> Realm {
        BLResultsControllerBaseTest.copyDummyRealmTo(url: dummyURLCopy(with: function))
        return realmCopy(with: function)
    }

    final func store(controller: ResultsController<Int, Todo>?, function: String = #function) {
        BLResultsControllerBaseTest.controllers[name] = controller
    }

    final func makeExpectation(_ name: String, function: String = #function) -> XCTestExpectation {
        return expectation(description: name + "|" + function)
    }

    final func cleanUp(function: String = #function) {
        BLResultsControllerBaseTest.deleteDummyRealmAt(url: dummyURLCopy(with: name))
        BLResultsControllerBaseTest.controllers[name] = nil
    }
}
