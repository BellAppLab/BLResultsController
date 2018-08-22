/*
 Copyright (c) 2018 Bell App Lab <apps@bellapplab.com>

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation


@objc
final class BLTimer: NSObject
{
    static func scheduleTimer(withTimeInterval interval: TimeInterval,
                              repeats: Bool,
                              block: @escaping (BLTimer) -> Swift.Void) -> BLTimer
    {
        return BLTimer(withTimeInterval: interval,
                       repeats: repeats,
                       block: block)
    }

    fileprivate let completion: (BLTimer) -> Swift.Void
    fileprivate weak var timer: Timer?

    deinit {
        invalidate()
    }

    private init(withTimeInterval interval: TimeInterval,
                 repeats: Bool,
                 block: @escaping (BLTimer) -> Swift.Void)
    {
        self.completion = block
        super.init()
        self.timer = Timer.scheduledTimer(timeInterval: interval,
                                          target: self,
                                          selector: #selector(handleTimer(_:)),
                                          userInfo: nil,
                                          repeats: repeats)
    }

    var isInvalidated: Bool {
        return timer == nil
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}


@objc
fileprivate extension BLTimer
{
    func handleTimer(_ timer: Timer) {
        completion(self)
    }
}
