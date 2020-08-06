import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerUpdates_Tests: BLResultsControllerBaseTest
{
    func testRemovingAWholeSection() {
        let realm = makeRealm()

        let dontExpectErrors = makeExpectation("We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectSectionToBeRemoved = makeExpectation("Expect a section to be removed from the ResultsController")
        let expectSectionTwoToBeRemoved = makeExpectation("Expect section with index 2 to be removed from the ResultsController")

        let dontExpectRowChangeToBeCalled = makeExpectation("We don't expect the row change callback to be called")
        dontExpectRowChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = makeExpectation("We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
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

        store(controller: controller)

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

        Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try realm.write {
                    let lowTodos = realm
                        .objects(Todo.self)
                        .filter("_priority == %@", Priority.low.rawValue)
                    print("LOW TODOS: \(lowTodos)")
                    realm.delete(lowTodos)
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

        cleanUp()
    }

    func testAddingAWholeSection() {
        let realm = makeRealm()

        let dontExpectErrors = makeExpectation("We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectSectionToBeAdded = makeExpectation("Expect a section to be added to the ResultsController")
        let expectSectionTwoToBeAdded = makeExpectation("Expect section with index 2 to be added to the ResultsController")

        let dontExpectRowChangeToBeCalled = makeExpectation("We don't expect the row change callback to be called")
        dontExpectRowChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = makeExpectation("We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        do {
            try realm.write {
                let lowTodos = realm
                    .objects(Todo.self)
                    .filter("_priority == %@", Priority.low.rawValue)
                print("LOW TODOS: \(lowTodos)")
                realm.delete(lowTodos)
            }
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
        }

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
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

        store(controller: controller)

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

        Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try realm.write {
                    let lowTodos = Priority.low.makeAllTodos()
                    print("LOW TODOS: \(lowTodos)")
                    realm.add(lowTodos)
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

        cleanUp()
    }

    func testRemovingItemsButNotSections() {
        let realm = makeRealm()

        let dontExpectErrors = makeExpectation("We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectRowsToBeRemoved = makeExpectation("Expect rows to be removed from the ResultsController")
        let expectLastRowsToBeRemoved = makeExpectation("Expect the row change callback to have 3 deletions")
        expectLastRowsToBeRemoved.expectedFulfillmentCount = 3

        let dontExpectSectionChangeToBeCalled = makeExpectation("We don't expect the section change callback to be called")
        dontExpectSectionChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = makeExpectation("We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        let dontExpectInsertionsToBeCalled = makeExpectation("We don't expect the row change callback to have insertions")
        dontExpectInsertionsToBeCalled.isInverted = true

        let dontExpectUpdatesToBeCalled = makeExpectation("We don't expect the row change callback to have updates")
        dontExpectUpdatesToBeCalled.isInverted = true

        let expectInitialSectionsToHave24Items = makeExpectation("Expect initial sections to have 24 items")
        expectInitialSectionsToHave24Items.expectedFulfillmentCount = 3

        let expectFinalSectionsToHave23Items = makeExpectation("Expect final sections to have 23 items")
        expectFinalSectionsToHave23Items.expectedFulfillmentCount = 3

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
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

        store(controller: controller)

        var expectedIndexItems = Set<IndexPath>()
        Priority.sortedCases.forEach {
            expectedIndexItems.insert(IndexPath(item: $0.letters.count - 1, section: $0.rawValue))
        }

        controller?.setChangeCallback { (change) in
            switch change {
            case .sectionUpdate(_, let insertedSections, let deletedSections):
                print("SECTION INSERTIONS: \(insertedSections)")
                print("SECTION DELETIONS: \(deletedSections)")
                dontExpectSectionChangeToBeCalled.fulfill()
            case .rowUpdate(let c, let insertedItems, let deletedItems, let updatedItems):
                expectRowsToBeRemoved.fulfill()
                XCTAssertFalse(deletedItems.isEmpty, "Deleted items should not be empty")
                print("INSERTIONS: \(insertedItems)")
                insertedItems.forEach { _ in
                    dontExpectInsertionsToBeCalled.fulfill()
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

        Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try realm.write {
                    let zTodos = realm
                        .objects(Todo.self)
                        .filter("letter == %@", "Z")
                    print("Z TODOS: \(zTodos)")
                    realm.delete(zTodos)
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
                   dontExpectInsertionsToBeCalled,
                   dontExpectUpdatesToBeCalled,
                   expectFinalSectionsToHave23Items,
                   expectInitialSectionsToHave24Items],
             timeout: 8)

        cleanUp()
    }

    func testAddingItemsButNotSections() {
        let realm = makeRealm()

        let dontExpectErrors = makeExpectation("We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectRowsToBeAdded = makeExpectation("Expect rows to be added from the ResultsController")
        let expectLastRowsToBeAdded = makeExpectation("Expect the row change callback to have 3 insertions")
        expectLastRowsToBeAdded.expectedFulfillmentCount = 3

        let dontExpectSectionChangeToBeCalled = makeExpectation("We don't expect the section change callback to be called")
        dontExpectSectionChangeToBeCalled.isInverted = true

        let dontExpectReloadToBeCalled = makeExpectation("We don't expect the reload callback to be called")
        dontExpectReloadToBeCalled.isInverted = true
        dontExpectReloadToBeCalled.expectedFulfillmentCount = 2

        let dontExpectDeletionsToBeCalled = makeExpectation("We don't exepct the row change callback to have deletions")
        dontExpectDeletionsToBeCalled.isInverted = true

        let dontExpectUpdatesToBeCalled = makeExpectation("We don't expect the row change callback to have updates")
        dontExpectUpdatesToBeCalled.isInverted = true

        let expectInitialSectionsToHave23Items = makeExpectation("Expect initial sections to have 23 items")
        expectInitialSectionsToHave23Items.expectedFulfillmentCount = 3

        let expectFinalSectionsToHave24Items = makeExpectation("Expect final sections to have 24 items")
        expectFinalSectionsToHave24Items.expectedFulfillmentCount = 3

        do {
            try realm.write {
                let zTodos = realm
                    .objects(Todo.self)
                    .filter("letter == %@", "Z")
                print("Z TODOS: \(zTodos)")
                realm.delete(zTodos)
            }
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
        }

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
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

        store(controller: controller)

        var expectedIndexItems = Set<IndexPath>()
        Priority.sortedCases.forEach {
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

        Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: false
        ) { (timer) in
            timer.invalidate()
            do {
                try realm.write {
                    let zTodos = Priority.sortedCases.map { $0.makeAllTodos().last! }
                    print("Z TODOS: \(zTodos)")
                    realm.add(zTodos)
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

        cleanUp()
    }
}
