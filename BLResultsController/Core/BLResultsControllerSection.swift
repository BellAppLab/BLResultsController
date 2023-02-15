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
import RealmSwift


/**
 A `ResultsControllerSection` is a property of your `Realm.Object` subclass that can be used to calculate sections in a `ResultsController`.

 Currently, the `ResultsController` only supports the following types as `Section`s:
    - `Bool`
    - `Int` (`Int8`, `Int16`, `Int32`, `Int64`)
    - `UInt` (`UInt8`, `UInt16`, `UInt32`, `UInt64`)
    - `Double`
    - `Float`
    - `String`
    - `Date`
    - `Data`

 Using `Object`s as a section values is **not** supported, but it's in the roadmap.
 */
public protocol ResultsControllerSection: Hashable {}


extension Bool: ResultsControllerSection {}
extension Int: ResultsControllerSection {}
extension Int8: ResultsControllerSection {}
extension Int16: ResultsControllerSection {}
extension Int32: ResultsControllerSection {}
extension Int64: ResultsControllerSection {}
extension UInt: ResultsControllerSection {}
extension UInt8: ResultsControllerSection {}
extension UInt16: ResultsControllerSection {}
extension UInt32: ResultsControllerSection {}
extension UInt64: ResultsControllerSection {}
extension Double: ResultsControllerSection {}
extension Float: ResultsControllerSection {}
extension String: ResultsControllerSection {}
extension Date: ResultsControllerSection {}
extension Data: ResultsControllerSection {}
