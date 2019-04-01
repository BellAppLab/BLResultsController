import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerUpdates_Tests: XCTestCase
{
    private static let testNames: [Int: String] = [
        0: "testRemovingAWholeSection",
        1: "testAddingAWholeSection",
        2: "testRemovingItemsButNotSections",
        3: "testAddingItemsButNotSections"
    ]

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

    override class func tearDown() {
        super.tearDown()

        testNames.forEach {
            deleteDummyRealmAt(url: dummyURLCopy(with: $0.value))
        }
    }

    func testRemovingAWholeSection() {
        let testNumber = 0
        BLResultsControllerUpdates_Tests.copyDummyRealmTo(url: dummyURLCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!))
        let tempRealm = realmCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!)

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectSectionToBeRemoved = expectation(description: "Expect a section to be removed from the ResultsController")
        let expectSectionTwoToBeRemoved = expectation(description: "Expect section with index 2 to be removed from the ResultsController")

        let dontExpectRowChangeToBeCalled = expectation(description: "We don't expect the row change callback to be called")
        dontExpectRowChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = expectation(description: "We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: tempRealm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        controller?.setChangeCallback { (change) in
            switch change {
            case .sectionUpdate(_, _, let deletedSections):
                expectSectionToBeRemoved.fulfill()
                XCTAssertFalse(deletedSections.isEmpty, "Deleted sections should not be empty")
                XCTAssertEqual(deletedSections.count, 1, "Deleted sections should contain 1 section index")
                XCTAssertEqual(deletedSections.first!, IndexSet(integer: 2), "Deleted sections should contain section with index 2")
                expectSectionTwoToBeRemoved.fulfill()
            case .rowUpdate(_, _, _, _):
                dontExpectRowChangeToBeCalled.fulfill()
            case .reload(_):
                dontExpectReloadToBeCalled.fulfill()
            }
        }

        controller?.start()

        BLTimer.scheduleTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try tempRealm.write {
                    let lowTodos = tempRealm
                        .objects(Todo.self)
                        .filter("_priority == %@", Priority.low.rawValue)
                    print("LOW TODOS: \(lowTodos)")
                    tempRealm.delete(lowTodos)
                }
            } catch {
                XCTFail("\(error)")
                dontExpectErrors.fulfill()
            }
        }

        wait(for: [dontExpectErrors,
                   expectSectionToBeRemoved,
                   expectSectionTwoToBeRemoved,
                   dontExpectRowChangeToBeCalled,
                   dontExpectReloadToBeCalled],
             timeout: 8)
    }

    func testAddingAWholeSection() {
        let testNumber = 1
        BLResultsControllerUpdates_Tests.copyDummyRealmTo(url: dummyURLCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!))
        let tempRealm = realmCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!)

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectSectionToBeAdded = expectation(description: "Expect a section to be added to the ResultsController")
        let expectSectionTwoToBeAdded = expectation(description: "Expect section with index 2 to be added to the ResultsController")

        let dontExpectRowChangeToBeCalled = expectation(description: "We don't expect the row change callback to be called")
        dontExpectRowChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = expectation(description: "We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        do {
            try tempRealm.write {
                let lowTodos = tempRealm
                    .objects(Todo.self)
                    .filter("_priority == %@", Priority.low.rawValue)
                print("LOW TODOS: \(lowTodos)")
                tempRealm.delete(lowTodos)
            }
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
        }

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: tempRealm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        controller?.setChangeCallback { (change) in
            switch change {
            case .sectionUpdate(_, let insertedSections, _):
                expectSectionToBeAdded.fulfill()
                XCTAssertFalse(insertedSections.isEmpty, "Inserted sections should not be empty")
                XCTAssertEqual(insertedSections.count, 1, "Inserted sections should contain 1 section index")
                XCTAssertEqual(insertedSections.first!, IndexSet(integer: 2), "Inserted sections should contain section with index 2")
                expectSectionTwoToBeAdded.fulfill()
            case .rowUpdate(_, _, _, _):
                dontExpectRowChangeToBeCalled.fulfill()
            case .reload(_):
                dontExpectReloadToBeCalled.fulfill()
            }
        }

        controller?.start()

        BLTimer.scheduleTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try tempRealm.write {
                    let lowTodos = Priority.low.makeAllTodos()
                    print("LOW TODOS: \(lowTodos)")
                    tempRealm.add(lowTodos)
                }
            } catch {
                XCTFail("\(error)")
                dontExpectErrors.fulfill()
            }
        }

        wait(for: [dontExpectErrors,
                   expectSectionToBeAdded,
                   expectSectionTwoToBeAdded,
                   dontExpectRowChangeToBeCalled,
                   dontExpectReloadToBeCalled],
             timeout: 8)
    }

    func testRemovingItemsButNotSections() {
        let testNumber = 2
        BLResultsControllerUpdates_Tests.copyDummyRealmTo(url: dummyURLCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!))
        let tempRealm = realmCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!)

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectRowsToBeRemoved = expectation(description: "Expect rows to be removed from the ResultsController")
        let expectLastRowsToBeRemoved = expectation(description: "Expect the row change callback to have 5 deletions")
        expectLastRowsToBeRemoved.expectedFulfillmentCount = 5

        let dontExpectSectionChangeToBeCalled = expectation(description: "We don't expect the section change callback to be called")
        dontExpectSectionChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = expectation(description: "We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        let expectInsertionsToBeCalled = expectation(description: "Expect the row change callback to have 2 insertions")
        expectInsertionsToBeCalled.expectedFulfillmentCount = 2

        let dontExpectUpdatesToBeCalled = expectation(description: "We don't expect the row change callback to have updates")
        dontExpectUpdatesToBeCalled.isInverted = true

        let expectInitialSectionsToHave24Items = expectation(description: "Expect initial sections to have 24 items")
        expectInitialSectionsToHave24Items.expectedFulfillmentCount = 3

        let expectFinalSectionsToHave23Items = expectation(description: "Expect final sections to have 23 items")
        expectFinalSectionsToHave23Items.expectedFulfillmentCount = 3

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: tempRealm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        var expectedIndexItems = Set<IndexPath>()
        Priority.allCases.forEach {
            expectedIndexItems.insert(IndexPath(item: $0.letters.count - 1, section: $0.rawValue))
        }

        controller?.setChangeCallback { (change) in
            switch change {
            case .sectionUpdate(_, _, _):
                dontExpectSectionChangeToBeCalled.fulfill()
            case .rowUpdate(let c, let insertedItems, let deletedItems, let updatedItems):
                expectRowsToBeRemoved.fulfill()
                XCTAssertFalse(deletedItems.isEmpty, "Deleted items should not be empty")
                print("INSERTIONS: \(insertedItems)")
                insertedItems.forEach { _ in
                    expectInsertionsToBeCalled.fulfill()
                }
                updatedItems.forEach { _ in
                    dontExpectUpdatesToBeCalled.fulfill()
                }
                print("DELETIONS: \(deletedItems)")
                expectedIndexItems.forEach {
                    XCTAssertTrue(deletedItems.contains($0), "Deleted items should contain index path \($0)")
                }
                deletedItems.forEach { _ in
                    expectLastRowsToBeRemoved.fulfill()
                }
                (0..<c.numberOfSections()).forEach {
                    guard let section = c.section(at: $0) else {
                        XCTFail("No section")
                        return
                    }
                    if c.numberOfItems(in: section) == 23 {
                        expectFinalSectionsToHave23Items.fulfill()
                    }
                }
            case .reload(let c):
                (0..<c.numberOfSections()).forEach {
                    guard let section = c.section(at: $0) else {
                        XCTFail("No section")
                        return
                    }
                    if c.numberOfItems(in: section) == 24 {
                        expectInitialSectionsToHave24Items.fulfill()
                    }
                }
                dontExpectReloadToBeCalled.fulfill()
            }
        }

        controller?.start()

        BLTimer.scheduleTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try tempRealm.write {
                    let zTodos = tempRealm
                        .objects(Todo.self)
                        .filter("letter == %@", "Z")
                    print("Z TODOS: \(zTodos)")
                    tempRealm.delete(zTodos)
                }
            } catch {
                XCTFail("\(error)")
                dontExpectErrors.fulfill()
            }
        }

        wait(for: [dontExpectErrors,
                   expectRowsToBeRemoved,
                   expectLastRowsToBeRemoved,
                   dontExpectSectionChangeToBeCalled,
                   dontExpectReloadToBeCalled,
                   expectInsertionsToBeCalled,
                   dontExpectUpdatesToBeCalled,
                   expectFinalSectionsToHave23Items,
                   expectInitialSectionsToHave24Items],
             timeout: 8)
    }

    func testAddingItemsButNotSections() {
        let testNumber = 3
        BLResultsControllerUpdates_Tests.copyDummyRealmTo(url: dummyURLCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!))
        let tempRealm = realmCopy(with: BLResultsControllerUpdates_Tests.testNames[testNumber]!)

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectRowsToBeAdded = expectation(description: "Expect rows to be added from the ResultsController")
        let expectLastRowsToBeAdded = expectation(description: "Expect the row change callback to have 3 insertions")
        expectLastRowsToBeAdded.expectedFulfillmentCount = 3

        let dontExpectSectionChangeToBeCalled = expectation(description: "We don't expect the section change callback to be called")
        dontExpectSectionChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = expectation(description: "We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        let dontExpectDeletionsToBeCalled = expectation(description: "We don't exepct the row change callback to have deletions")
        dontExpectDeletionsToBeCalled.isInverted = true

        let dontExpectUpdatesToBeCalled = expectation(description: "We don't expect the row change callback to have updates")
        dontExpectUpdatesToBeCalled.isInverted = true

        let expectInitialSectionsToHave23Items = expectation(description: "Expect initial sections to have 23 items")
        expectInitialSectionsToHave23Items.expectedFulfillmentCount = 3

        let expectFinalSectionsToHave24Items = expectation(description: "Expect final sections to have 24 items")
        expectFinalSectionsToHave24Items.expectedFulfillmentCount = 3

        do {
            try tempRealm.write {
                let zTodos = tempRealm
                    .objects(Todo.self)
                    .filter("letter == %@", "Z")
                print("Z TODOS: \(zTodos)")
                tempRealm.delete(zTodos)
            }
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
        }

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: tempRealm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        var expectedIndexItems = Set<IndexPath>()
        Priority.allCases.forEach {
            expectedIndexItems.insert(IndexPath(item: $0.letters.count - 1, section: $0.rawValue))
        }

        controller?.setChangeCallback { (change) in
            switch change {
            case .sectionUpdate(_, _, _):
                dontExpectSectionChangeToBeCalled.fulfill()
            case .rowUpdate(let c, let insertedItems, let deletedItems, let updatedItems):
                expectRowsToBeAdded.fulfill()
                XCTAssertFalse(insertedItems.isEmpty, "Inserted items should not be empty")
                print("INSERTIONS: \(insertedItems)")
                insertedItems.forEach { _ in
                    expectLastRowsToBeAdded.fulfill()
                }
                expectedIndexItems.forEach {
                    XCTAssertTrue(insertedItems.contains($0), "Inserted items should contain index path \($0)")
                }
                updatedItems.forEach { _ in
                    dontExpectUpdatesToBeCalled.fulfill()
                }
                deletedItems.forEach { _ in
                    dontExpectDeletionsToBeCalled.fulfill()
                }
                (0..<c.numberOfSections()).forEach {
                    guard let section = c.section(at: $0) else {
                        XCTFail("No section")
                        return
                    }
                    if c.numberOfItems(in: section) == 24 {
                        expectFinalSectionsToHave24Items.fulfill()
                    }
                }
            case .reload(let c):
                (0..<c.numberOfSections()).forEach {
                    guard let section = c.section(at: $0) else {
                        XCTFail("No section")
                        return
                    }
                    if c.numberOfItems(in: section) == 23 {
                        expectInitialSectionsToHave23Items.fulfill()
                    }
                }
                dontExpectReloadToBeCalled.fulfill()
            }
        }

        controller?.start()

        BLTimer.scheduleTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try tempRealm.write {
                    let zTodos = Priority.allCases.map { $0.makeAllTodos().last! }
                    print("Z TODOS: \(zTodos)")
                    tempRealm.add(zTodos)
                }
            } catch {
                XCTFail("\(error)")
                dontExpectErrors.fulfill()
            }
        }

        wait(for: [dontExpectErrors,
                   expectRowsToBeAdded,
                   expectLastRowsToBeAdded,
                   dontExpectSectionChangeToBeCalled,
                   dontExpectReloadToBeCalled,
                   dontExpectDeletionsToBeCalled,
                   dontExpectUpdatesToBeCalled,
                   expectInitialSectionsToHave23Items,
                   expectFinalSectionsToHave24Items],
             timeout: 8)
    }
}
