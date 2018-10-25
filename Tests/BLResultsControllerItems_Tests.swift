import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerItems_Tests: XCTestCase
{
    func testNumberOfItemsInSection() {
        var allItems = [Priority: Int]()
        realm.objects(Todo.self).forEach {
            var count = allItems[$0.priority] ?? 0
            count += 1
            allItems[$0.priority] = count
        }

        let expectNumberOfSections = expectation(description: "Expect number of sections to be \(allItems.keys.count)")

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectNumberOfItems1 = expectation(description: "Expect number of items in section \(Priority.high) to be \(allItems[Priority.high]!)")
        let expectNumberOfItems2 = expectation(description: "Expect number of items in section \(Priority.default) to be \(allItems[Priority.default]!)")
        let expectNumberOfItems3 = expectation(description: "Expect number of items in section \(Priority.low) to be \(allItems[Priority.low]!)")

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

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), allItems.keys.count, "Number of sections should be \(allItems.keys.count)")
                expectNumberOfSections.fulfill()

                Priority.allCases.forEach {
                    let index = c.indexOf(section: $0.rawValue)
                    XCTAssertNotNil(index, "Index of section \($0) should not be nil")
                    let numberOfItems = c.numberOfItems(in: index!)
                    XCTAssertEqual(numberOfItems, allItems[$0]!, "Number of items in section \($0) should be equal to \(allItems[$0]!), but found \(numberOfItems)")

                    switch $0 {
                    case .high:
                        expectNumberOfItems1.fulfill()
                    case .default:
                        expectNumberOfItems2.fulfill()
                    case .low:
                        expectNumberOfItems3.fulfill()
                    }
                }

                controller = nil
            default:
                break
            }
        }

        controller?.start()

        wait(for: [expectNumberOfSections,
                   expectNumberOfItems1,
                   expectNumberOfItems2,
                   expectNumberOfItems3,
                   dontExpectErrors],
             timeout: 4)
    }

    func testItemAtIndexPath() {
        let letters = [
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "X", "Z"
        ]
        func text(at row: Int) -> String {
            return "Fix Thing \(letters[row])"
        }

        let ascending = false

        let sortDescriptors = [
            SortDescriptor(keyPath: "_priority",
                           ascending: ascending),
            SortDescriptor(keyPath: "text",
                           ascending: true)
        ]

        var allItems = [Priority: [IndexPath]]()
        var allExpectations: [Priority: XCTestExpectation] = [:]
        Priority.allCases.forEach {
            let results = realm
                .objects(Todo.self)
                .filter("_priority == %@", $0.rawValue)
                .sorted(by: sortDescriptors)
            results.enumerated().forEach {
                let section = ascending ? $1.priority.rawValue : $1.priority.opposite.rawValue
                var indexPaths = allItems[$1.priority] ?? []
                indexPaths.append(IndexPath(item: $0,
                                            section: section))
                allItems[$1.priority] = indexPaths

                var exp: XCTestExpectation
                if let temp = allExpectations[$1.priority] {
                    exp = temp
                    exp.expectedFulfillmentCount += 1
                } else {
                    exp = expectation(description: "Expect section \($0) at index \(section) to have correct items")
                }
                allExpectations[$1.priority] = exp
            }
        }

        let allResultsCount = realm
            .objects(Todo.self)
            .sorted(by: sortDescriptors)
            .count

        XCTAssertEqual(allItems.reduce(0, { $0 + $1.value.count }), allResultsCount, "All items' count should be equal to the total number of elements \(allResultsCount)")

        print("ALL ITEMS: \(allItems)")

        let expectNumberOfSections = expectation(description: "Expect number of sections to be \(allItems.keys.count)")

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: sortDescriptors
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        let expectIndexTitlesToBeNil = expectation(description: "Index titles should be nil, because we did not set the `setFormatSectionIndexTitleCallback`")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), allItems.keys.count, "Number of sections should be \(allItems.keys.count)")
                expectNumberOfSections.fulfill()

                XCTAssertNil(c.indexTitles(), "Index titles should be nil, because we did not set the `setFormatSectionIndexTitleCallback`")
                expectIndexTitlesToBeNil.fulfill()

                allItems.forEach { priority, indexPaths in
                    indexPaths.forEach { indexPath in
                        guard let item = c.item(at: indexPath) else {
                            XCTFail("Couldn't find item at index path \(indexPath)")
                            abort()
                        }
                        guard let expectation = allExpectations[priority] else {
                            XCTFail("WAT?")
                            abort()
                        }

                        XCTAssertEqual(priority, item.priority, "Item \(item) at index path \(indexPath) should have priority \(priority), but found \(item.priority)")
                        XCTAssertEqual(text(at: indexPath.item), item.text, "Text for item \(item) at index path \(indexPath) should be \(text(at: indexPath.item)), but found \(item.text)")

                        expectation.fulfill()
                    }
                }
                controller = nil
            default:
                break
            }
        }

        var expectationsArray = allExpectations.map { $0.value }
        expectationsArray.append(expectNumberOfSections)
        expectationsArray.append(dontExpectErrors)
        expectationsArray.append(expectIndexTitlesToBeNil)

        controller?.start()

        wait(for: expectationsArray,
             timeout: 8)
    }
}


class BLResultsControllerTitles_Tests: XCTestCase
{
    func testSectionTitles() {
        let expectNumberOfSections = expectation(description: "Expect number of sections to be \(Priority.allCases.count)")

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectNumberOfItems1 = expectation(description: "Expect the section at index 0 to have a title \"\(Priority.high.title)\"")
        let expectNumberOfItems2 = expectation(description: "Expect the section at index 1 to have a title \"\(Priority.default.title)\"")
        let expectNumberOfItems3 = expectation(description: "Expect the section at index 2 to have a title \"\(Priority.low.title)\"")

        let ascending = false

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: ascending)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        let dontExpectNilIndexTitles = expectation(description: "Index titles should not be nil, because we have set the `setFormatSectionIndexTitleCallback`")
        dontExpectNilIndexTitles.isInverted = true

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), Priority.allCases.count, "Number of sections should be \(Priority.allCases.count)")
                expectNumberOfSections.fulfill()

                let indexTitles = c.indexTitles()
                if indexTitles == nil {
                    dontExpectNilIndexTitles.fulfill()
                }
                XCTAssertNotNil(indexTitles, "Index titles should not be nil, because we have set the `setFormatSectionIndexTitleCallback`")
                XCTAssertEqual(indexTitles?.count, Priority.allCases.count, "Index titles should have \(Priority.allCases.count) items, but found \(indexTitles?.count ?? 0)")

                Priority
                    .allCases
                    .sorted(by: { ascending ? $0.rawValue < $1.rawValue : $0.rawValue > $1.rawValue })
                    .enumerated()
                    .forEach {
                        let title = indexTitles?[$0]
                        XCTAssertNotNil(title, "Index title at index \($0) should not be nil")
                        XCTAssertEqual(title!, $1.title, "Index title at index \($0) should be equal to \($1.title)")

                        switch $1 {
                        case .high:
                            expectNumberOfItems1.fulfill()
                        case .default:
                            expectNumberOfItems2.fulfill()
                        case .low:
                            expectNumberOfItems3.fulfill()
                        }
                    }

                controller = nil
            default:
                break
            }
        }

        controller?.setFormatSectionIndexTitleCallback { (section, _) -> String in
            return Priority(rawValue: section)?.title ?? ""
        }

        controller?.start()

        wait(for: [expectNumberOfSections,
                   expectNumberOfItems1,
                   expectNumberOfItems2,
                   expectNumberOfItems3,
                   dontExpectErrors,
                   dontExpectNilIndexTitles],
             timeout: 4)
    }

    func testSortingIndexTitles() {
        let ascending = false
        let allCases = Priority.allCases.sorted(by: { ascending ? $0.title < $1.title : $0.title > $1.title })
        let expectNumberOfSections = expectation(description: "Expect number of sections to be \(allCases.count)")

        let dontExpectErrors = expectation(description: "We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let expectNumberOfItems1 = expectation(description: "Expect the section at index 0 to have a title \"\(Priority.high.title)\"")
        let expectNumberOfItems2 = expectation(description: "Expect the section at index 1 to have a title \"\(Priority.default.title)\"")
        let expectNumberOfItems3 = expectation(description: "Expect the section at index 2 to have a title \"\(Priority.low.title)\"")

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: ascending)
                ]
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        let dontExpectNilIndexTitles = expectation(description: "Index titles should not be nil, because we have set the `setFormatSectionIndexTitleCallback`")
        dontExpectNilIndexTitles.isInverted = true

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), allCases.count, "Number of sections should be \(allCases.count)")
                expectNumberOfSections.fulfill()

                let indexTitles = c.indexTitles()
                if indexTitles == nil {
                    dontExpectNilIndexTitles.fulfill()
                }
                XCTAssertNotNil(indexTitles, "Index titles should not be nil, because we have set the `setFormatSectionIndexTitleCallback`")
                XCTAssertEqual(indexTitles?.count, allCases.count, "Index titles should have \(allCases.count) items, but found \(indexTitles?.count ?? 0)")

                allCases
                    .enumerated()
                    .forEach {
                        let title = indexTitles?[$0]
                        XCTAssertNotNil(title, "Index title at index \($0) should not be nil")
                        XCTAssertEqual(title!, $1.title, "Index title at index \($0) should be equal to \($1.title)")

                        switch $1 {
                        case .high:
                            expectNumberOfItems1.fulfill()
                        case .default:
                            expectNumberOfItems2.fulfill()
                        case .low:
                            expectNumberOfItems3.fulfill()
                        }
                }

                controller = nil
            default:
                break
            }
        }

        controller?.setFormatSectionIndexTitleCallback { (section, _) -> String in
            return Priority(rawValue: section)?.title ?? ""
        }

        controller?.setSortSectionIndexTitles { (titles, _) in
            titles.sort(by: { ascending ? $0 < $1 : $0 > $1 })
        }

        controller?.start()

        wait(for: [expectNumberOfSections,
                   expectNumberOfItems1,
                   expectNumberOfItems2,
                   expectNumberOfItems3,
                   dontExpectErrors,
                   dontExpectNilIndexTitles],
             timeout: 4)
    }
}
