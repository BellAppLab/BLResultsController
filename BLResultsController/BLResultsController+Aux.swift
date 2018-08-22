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

import RealmSwift


//MARK: - RESULTS CONTROLLER DELEGATE
/// Defines how the Results Controller reports changes to the underlaying data model
public protocol ResultsControllerDelegate: AnyObject {
    func resultsControllerDidReloadData<Section: Hashable, Element: Object>(_ controller: ResultsController<Section, Element>)
    func resultsController<Section: Hashable, Element: Object>(_ controller: ResultsController<Section, Element>,
                                                               didInsertSections insertedSections: [IndexSet],
                                                               andDeleteSections deletedSections: [IndexSet])
    func resultsController<Section: Hashable, Element: Object>(_ controller: ResultsController<Section, Element>,
                                                               didInsertItems insertedItems: [IndexPath],
                                                               deleteItems deletedItems: [IndexPath],
                                                               andUpdateItems updatedItems: [IndexPath])
}

//MARK: - RESULTS CONTROLLER DELEGATE
/// Defines how the Results Controller reports changes to the underlaying data model
public protocol ResultsControllerSectionTitleFormatter: AnyObject {
    func formatSectionTitle<Section: Hashable, Element: Object>(for section: Section,
                                                                in controller: ResultsController<Section, Element>) -> String
    func sortSectionTitles<Section: Hashable, Element: Object>(_ titles: [String],
                                                               for controller: ResultsController<Section, Element>) -> [String]
}
