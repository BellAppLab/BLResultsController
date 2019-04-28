import XCTest
import RealmSwift
@testable import Example
@testable import BLResultsController


class BLResultsControllerSetup_Tests: BLResultsControllerBaseTest
{
    var tempController: ResultsController<Int, Todo>?

    func testInitErrors() {
        let realm = makeRealm()

        XCTAssertThrowsError(
            try ResultsController<Int, Todo>(
                realm: realm,
                sectionNameKeyPath: "",
                sortDescriptors: []
            ),
            "A `noSectionNameKeyPath` exception is expected here"
        ) { (error) in
            guard let _ = error as? ResultsControllerError else {
                XCTFail("A `noSectionNameKeyPath` exception is expected here")
                return
            }
        }
        XCTAssertThrowsError(
            try ResultsController<Int, Todo>(
                realm: realm,
                sectionNameKeyPath: "section",
                sortDescriptors: []
            ),
            "A `noSortDescriptors` exception is expected here"
        ) { (error) in
            guard let _ = error as? ResultsControllerError else {
                XCTFail("A `noSortDescriptors` exception is expected here")
                return
            }
        }
        XCTAssertThrowsError(
            try ResultsController<Int, Todo>(
                realm: realm,
                sectionNameKeyPath: "section",
                sortDescriptors: [SortDescriptor(keyPath: "_priority")]
            ),
            "A `sortDescriptorMismatch` exception is expected here"
        ) { (error) in
            guard let _ = error as? ResultsControllerError else {
                XCTFail("A `sortDescriptorMismatch` exception is expected here")
                return
            }
        }
        XCTAssertThrowsError(
            try ResultsController<Int, Todo>(
                realm: realm,
                sectionNameKeyPath: "section",
                sortDescriptors: [SortDescriptor(keyPath: "section")]
            ),
            "A `invalidSchema` exception is expected here"
        ) { (error) in
            guard let _ = error as? ResultsControllerError else {
                XCTFail("A `invalidSchema` exception is expected here")
                return
            }
        }
        XCTAssertThrowsError(
            try ResultsController<String, Todo>(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [SortDescriptor(keyPath: "_priority")]
            ),
            "A `propertyTypeMismatch` exception is expected here"
        ) { (error) in
            guard let _ = error as? ResultsControllerError else {
                XCTFail("A `propertyTypeMismatch` exception is expected here")
                return
            }
        }
        XCTAssertNoThrow(
            tempController = try ResultsController<Int, Todo>(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [SortDescriptor(keyPath: "_priority")]
            ),
            "No exceptions should be thrown here"
        )

        let dontExpectCallbackToBeCalled = makeExpectation("Change callback should not be called, because we haven't started the BackgroundRealm")
        dontExpectCallbackToBeCalled.isInverted = true

        tempController?.setChangeCallback { (_) in
            dontExpectCallbackToBeCalled.fulfill()
        }

        let expectEverythingToBeAlright = makeExpectation("Everything should be alright")

        BLTimer.scheduleTimer(withTimeInterval: 2,
                              repeats: false)
        { [weak self] (timer) in
            timer.invalidate()
            self?.tempController = nil
            expectEverythingToBeAlright.fulfill()
        }

        wait(for: [expectEverythingToBeAlright,
                   dontExpectCallbackToBeCalled],
             timeout: 4)

        cleanUp()
    }

    func testChangingParameters() {
        let realm = makeRealm()

        let reloadTotal = 2
        var reloadCount = 1

        let expectTwoReloads = makeExpectation("Expect the ResultsController to reload twice, since we're changing its parameters")
        expectTwoReloads.expectedFulfillmentCount = reloadTotal

        let dontExpectErrors = makeExpectation("We don't expect errors to happen when starting the ResultsController")
        dontExpectErrors.isInverted = true

        let sectionNameKeyPath = "_priority"

        let firstSortDescriptors = [
            SortDescriptor(keyPath: sectionNameKeyPath,
                           ascending: false)
        ]
        let secondSortDescriptors = [
            SortDescriptor(keyPath: sectionNameKeyPath,
                           ascending: true)
        ]

        var controller: ResultsController<Int, Todo>?
        do {
            controller = try ResultsController(
                realm: realm,
                sectionNameKeyPath: sectionNameKeyPath,
                sortDescriptors: firstSortDescriptors
            )
        } catch {
            XCTFail("\(error)")
            dontExpectErrors.fulfill()
            return
        }

        store(controller: controller)

        XCTAssertNotNil(controller, "Controller should not be nil at this point")

        controller?.setChangeCallback { (change) in
            switch change {
            case .reload(let c):
                XCTAssertEqual(c.numberOfSections(), Priority.allCases.count, "Number of sections should be \(Priority.allCases.count)")

                var allSections: [Priority]
                if reloadCount == 1 {
                    allSections = Priority
                        .allCases
                        .sorted(by: { $0 > $1 })
                } else if reloadCount == 2 {
                    allSections = Priority
                        .allCases
                        .sorted(by: { $0 < $1 })
                } else {
                    XCTFail("This should never happen")
                    return
                }

                allSections.enumerated().forEach {
                    guard let s = c.section(at: $0), let section = Priority(rawValue: s) else {
                        XCTFail("No section")
                        return
                    }
                    XCTAssertNotNil(section, "Transforming a section into a Priority should not render a nil result")
                    XCTAssertEqual(section, $1, "Section \(section) with rawValue \(section.rawValue) should be equal to \($1)")
                }

                if reloadCount == 1 {
                    do {
                        try c.change(sortDescriptors: secondSortDescriptors)
                    } catch {
                        XCTFail("Changing sort descriptors should not throw; Error: \(error)")
                        dontExpectErrors.fulfill()
                    }
                }

                if reloadCount == reloadTotal {
                    controller = nil
                }
                reloadCount += 1

                expectTwoReloads.fulfill()
            default:
                break
            }
        }

        controller?.start()

        wait(for: [expectTwoReloads, dontExpectErrors],
             timeout: 4)

        cleanUp()
    }
}
