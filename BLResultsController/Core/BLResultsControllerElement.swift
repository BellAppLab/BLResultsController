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
import class RealmSwift.Object

/**
 The `ResultsControllerElement` protocol defines the way by which the `ResultsController` will uniquely identify each object within its results.

 ## Example

 ```swift
 public final class Foo: Object, ResultsControllerElement
 {
    //If your class doesn't have a unique identifier yet, do this
    public dynamic var resultsControllerId: String = UUID().uuidString

     //If it does, you can do this
     public var resultsControllerId: String {
         return <#id#>
     }
 }
 ```
 */
public protocol ResultsControllerElement: Object {
    associatedtype ResultsControllerID: Hashable
    var resultsControllerId: ResultsControllerID { get }
}

public extension ResultsControllerElement where Self: Identifiable {
    var resultsControllerId: ID { id }
}


struct InternalElement<Key: ResultsControllerSection, Element: ResultsControllerElement>: Hashable, Equatable, Collection
{
    let items: [Element.ResultsControllerID]
    let key: Key

    typealias Index = Int

    var startIndex: Int {
        return items.startIndex
    }

    var endIndex: Int {
        return items.endIndex
    }

    subscript(i: Int) -> Element.ResultsControllerID {
        return items[i]
    }

    func index(after i: Int) -> Int {
        return items.index(after: i)
    }

    init(items: [Element.ResultsControllerID] = [],
         key: Key)
    {
        self.items = items
        self.key = key
    }

    init(element: Element,
         key: Key)
    {
        self.init(items: [element.resultsControllerId],
                  key: key)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.hashValue)
    }

    static func ==(lhs: InternalElement<Key, Element>,
                   rhs: InternalElement<Key, Element>) -> Bool
    {
        return lhs.key == rhs.key
    }
}


extension InternalElement
{
    mutating func insertElement(_ element: Element) {
        var items = self.items
        items.append(element.resultsControllerId)
        self = InternalElement(items: items,
                               key: key)
    }
}


extension Array
{
    func indexPathsOfElements<S: ResultsControllerSection, E: ResultsControllerElement>(indices: [Int]) -> [IndexPath] where Element == InternalElement<S, E>
    {
        guard indices.isEmpty == false else { return [] }
        let enumerated = self.enumerated()
        var countSoFar = 0
        return indices.compactMap { i in
            precondition(i > -1, "Index should be greater than or equal to 0")
            if let (section, _) = enumerated.first(where: { (sectionIndex, element) -> Bool in
                if i < (element.count + countSoFar) {
                    return true
                }
                countSoFar += element.count
                return false
            })
            {
                return IndexPath(item: i - countSoFar,
                                 section: section)
            }
            return nil
        }
    }
}
