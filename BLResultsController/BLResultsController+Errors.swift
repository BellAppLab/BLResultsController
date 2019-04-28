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
import enum RealmSwift.PropertyType


/**
 Errors that may be thrown by a `ResultsController`.
 */
public enum ResultsControllerError: Swift.Error, CustomStringConvertible {
    /// Trying to initialise a `ResultsController` with an empty `sortDescriptors` parameter.
    case noSortDescriptors
    /// Trying to initialise a `ResultsController` with an empty `sectionNameKeyPath` parameter.
    case noSectionNameKeyPath
    /// Trying to initialise a `ResultsController` with the first `SortDescriptor`'s key path being different than `sectionNameKeyPath`.
    case sortDescriptorMismatch(sortDescriptorKeyPath: String, sectionNameKeyPath: String)
    /// Trying to initialise a `ResultsController` with an `Element` whose `sharedSchema()` is `nil`. This should never happen really, but you never know...
    case noSchema(elementType: Object.Type)
    /// Trying to initialise a `ResultsController` but `sectionNameKeyPath` is not a valid key path of `Element`. In other words, if there is no property in your object that can be accessed via `sectionNameKeyPath`.
    case invalidSchema(elementType: Object.Type, sectionNameKeyPath: String)
    /// Trying to initialise a `ResultsController` but the property returned by your `Element`'s `sectionNameKeyPath` is not of the same type as this controller's `Section`.
    case propertyTypeMismatch(propertyType: Any.Type, expectedPropertyType: PropertyType)

    public var localizedDescription: String {
        switch self {
        case .noSortDescriptors:
            return "The ResultsController must have at least one sort descriptor."
        case .noSectionNameKeyPath:
            return "The ResultsController cannot be instatiated with an empty section name key path."
        case .sortDescriptorMismatch(let sortDescriptorKeyPath, let sectionNameKeyPath):
            return "A ResultsController's sectionNameKeyPath must be equal to the first sort descriptor's keyPath.\nSort Descriptor Key Path: \(sortDescriptorKeyPath)\nSection Name Key Path: \(sectionNameKeyPath)."
        case .noSchema(let elementType):
            return "Trying to create a ResultsController with \(String(describing: elementType.self)), but not object schema has been found."
        case .invalidSchema(let elementType, let sectionNameKeyPath):
            return "Trying to create a ResultsController with \(String(describing: elementType.self)), but its object schema doesn't contain any properties for the key path \(sectionNameKeyPath)."
        case .propertyTypeMismatch(let propertyType, let expectedPropertyType):
            return "Trying to create a ResultsController using \(String(describing: propertyType.self)) as a section, but expected a \(expectedPropertyType)."
        }
    }

    public var description: String {
        return localizedDescription
    }
}
