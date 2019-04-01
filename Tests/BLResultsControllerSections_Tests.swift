import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerSections_Tests: XCTestCase
{
    func testNumberOfSections() {
        let numberOfSections = Priority.allCases.count
        let expectNumberOfSections = expectation(description: "Expect number of sections to be \(numberOfSections)")

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
            expectNumberOfSections.fulfill()
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), numberOfSections, "Number of sections should be \(numberOfSections)")
                controller = nil
                expectNumberOfSections.fulfill()
            default:
                break
            }
        }

        controller?.start()

        wait(for: [expectNumberOfSections],
             timeout: 4)
    }

    func testSectionAtIndex() {
        let allSections = Priority.allCases.sorted(by: { $0.rawValue > $1.rawValue })
        print("ALL SECTIONS: \(allSections)")

        XCTAssertTrue(allSections.count == 3, "All Sections should have 3 elements")

        let allExpectations = allSections.enumerated().map {
            expectation(description: "Expect section number \($0) to be \($1)")
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
            allExpectations.forEach { $0.fulfill() }
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                allSections.enumerated().forEach {
                    guard let s = c.section(at: $0), let section = Priority(rawValue: s) else {
                        XCTFail("No section")
                        return 
                    }
                    XCTAssertNotNil(section, "Transforming a section into a Priority should not render a nil result")
                    XCTAssertEqual(section, $1, "Section \(section) with rawValue \(section.rawValue) should be equal to \($1)")
                }
                controller = nil
                allExpectations.forEach { $0.fulfill() }
            default:
                break
            }
        }

        controller?.start()

        wait(for: allExpectations,
             timeout: 12)
    }

    func testIndexOfSection() {
        let allSections = Priority.allCases.sorted(by: { $0.rawValue > $1.rawValue })
        print("ALL SECTIONS: \(allSections)")

        XCTAssertTrue(allSections.count == 3, "All Sections should have 3 elements")

        let allExpectations = allSections.enumerated().map {
            expectation(description: "Expect section \($1) to have index \($0)")
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
            allExpectations.forEach { $0.fulfill() }
            return
        }

        XCTAssertNotNil(controller, "Controller should not be nil at this point")
        XCTAssertTrue(controller?.numberOfSections() == 0, "At this point, numberOfSections should be 0")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                allSections.enumerated().forEach {
                    let index = c.indexOf(section: $1.rawValue)
                    XCTAssertNotNil(index, "Index of section \($1) with rawValue \($1.rawValue) should not be nil")
                    XCTAssertEqual(index!, $0, "Index of section \($1) with rawValue \($1.rawValue) should be equal to \(index!) ")
                }
                controller = nil
                allExpectations.forEach { $0.fulfill() }
            default:
                break
            }
        }

        controller?.start()

        wait(for: allExpectations,
             timeout: 12)
    }
}
