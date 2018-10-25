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


public enum ResultsControllerError: Error {
    case noSortDescriptors
    case noSectionNameKeyPath
    case sortDescriptorMismatch(sortDescriptorKeyPath: String, sectionNameKeyPath: String)
    case noSchema(elementType: Object.Type)
    case invalidSchema(elementType: Object.Type, sectionNameKeyPath: String)
    case propertyTypeMismatch(propertyType: Any.Type, expectedPropertyType: PropertyType)

    var localizedDescription: String {
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
}
