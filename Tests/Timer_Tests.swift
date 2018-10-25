import XCTest


class Timer_Tests: XCTestCase
{
    func testTimerFires() {
        let expectTimerFiring = expectation(description: "BLTimer should fire")
        let _ = BLTimer.scheduleTimer(withTimeInterval: 0.5,
                                      repeats: false)
        { (timer) in
            expectTimerFiring.fulfill()
        }

        wait(for: [expectTimerFiring],
             timeout: 1.0)
    }

    func testWeakTimerFires() {
        let expectTimerFiring = expectation(description: "Weak BLTimer should fire")
        weak var _: BLTimer? = BLTimer.scheduleTimer(withTimeInterval: 0.5,
                                                     repeats: false)
        { (timer) in
            expectTimerFiring.fulfill()
        }

        wait(for: [expectTimerFiring],
             timeout: 1.0)
    }

    func testInvalidatedTimerDoesNotFire() {
        let expectTimerFiring = expectation(description: "Invalidated BLTimer should NOT fire")
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
