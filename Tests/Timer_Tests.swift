import XCTest


class Timer_Tests: BLResultsControllerBaseTest
{
    func testTimerFires() {
        let expectTimerFiring = makeExpectation("BLTimer should fire")
        let _ = BLTimer.scheduleTimer(withTimeInterval: 0.5,
                                      repeats: false)
        { (timer) in
            expectTimerFiring.fulfill()
        }

        wait(for: [expectTimerFiring],
             timeout: 1.0)
    }

    func testWeakTimerFires() {
        let expectTimerFiring = makeExpectation("Weak BLTimer should fire")
        weak var _: BLTimer? = BLTimer.scheduleTimer(withTimeInterval: 0.5,
                                                     repeats: false)
        { (timer) in
            expectTimerFiring.fulfill()
        }

        wait(for: [expectTimerFiring],
             timeout: 1.0)
    }

    func testInvalidatedTimerDoesNotFire() {
        let expectTimerFiring = makeExpectation("Invalidated BLTimer should NOT fire")
        expectTimerFiring.isInverted = true

        let timer = BLTimer.scheduleTimer(withTimeInterval: 0.5,
                                          repeats: false)
        { (timer) in
            expectTimerFiring.fulfill()
        }
        timer.invalidate()

        wait(for: [expectTimerFiring],
             timeout: 1.0)
    }
}
