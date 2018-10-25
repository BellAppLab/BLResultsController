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

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#endif


//MARK: - RESULTS CONTROLLER
public final class ResultsController<Section: ResultsControllerSection, Element: Object>
{
    //MARK: - Public Interface
    public let realm: Realm

    public private(set) var predicates: [NSPredicate]
    public private(set) var sortDescriptors: [SortDescriptor]
    public private(set) var sectionNameKeyPath: String

    public func change(predicates: [NSPredicate]? = nil,
                       sortDescriptors: [SortDescriptor]? = nil,
                       sectionNameKeyPath: String? = nil) throws
    {
        precondition(Thread.current == Thread.main, "\(String(describing: self)) must only have its settings changed from the main thread.")

        if let predicates = predicates {
            self.predicates = predicates
        }
        if let sortDescriptors = sortDescriptors {
            self.sortDescriptors = sortDescriptors
        }
        if let sectionNameKeyPath = sectionNameKeyPath {
            self.sectionNameKeyPath = sectionNameKeyPath
        }

        try validateParameters()

        setup()
    }

    public var objects: Results<Element> {
        return realm
            .objects(Element.self)
            .applying(predicates: allPredicates,
                      sortDescriptors: sortDescriptors)
    }

    //MARK: Callbacks
    public enum ChangeCallback {
        case reload(controller: ResultsController<Section, Element>)
        case sectionUpdate(controller: ResultsController<Section, Element>, insertedSections: [IndexSet], deletedSections: [IndexSet])
        case rowUpdate(controller: ResultsController<Section, Element>, insertedItems: [IndexPath], deletedItems: [IndexPath], updatedItems: [IndexPath])
    }

    fileprivate var _changeCallback: ((ResultsController.ChangeCallback) -> Void)?
    public func setChangeCallback(_ change: ((ResultsController.ChangeCallback) -> Void)?) {
        _changeCallback = change
    }

    public typealias SectionIndexTitleCallback = (_ section: Section, _ controller: ResultsController<Section, Element>) -> String
    fileprivate var _formatSectionIndexTitleCallback: ResultsController.SectionIndexTitleCallback?
    public func setFormatSectionIndexTitleCallback(_ callback: ResultsController.SectionIndexTitleCallback?) {
        _formatSectionIndexTitleCallback = callback
    }

    public typealias SortSectionIndexTitlesCallback = (_ indexTitles: inout [String], _ controller: ResultsController<Section, Element>) -> Void
    fileprivate var _sortSectionIndexTitlesCallback: ResultsController.SortSectionIndexTitlesCallback?
    public func setSortSectionIndexTitles(_ callback: ResultsController.SortSectionIndexTitlesCallback?) {
        _sortSectionIndexTitlesCallback = callback
    }

    public init(realm: Realm,
                predicates: [NSPredicate] = [],
                sectionNameKeyPath: String,
                sortDescriptors: [SortDescriptor]) throws
    {
        self.realm = realm
        self.predicates = predicates
        self.sortDescriptors = sortDescriptors
        self.sectionNameKeyPath = sectionNameKeyPath

        precondition(Thread.current == Thread.main, "\(String(describing: self)) must only be instantiated from the main thread.")

        try validateParameters()
    }

    private func validateParameters() throws {
        guard sortDescriptors.isEmpty == false else {
            throw ResultsControllerError.noSortDescriptors
        }
        guard sectionNameKeyPath.isEmpty == false else {
            throw ResultsControllerError.noSectionNameKeyPath
        }
        guard sortDescriptors.first!.keyPath == sectionNameKeyPath else {
            throw ResultsControllerError.sortDescriptorMismatch(sortDescriptorKeyPath: sortDescriptors.first!.keyPath,
                                                                sectionNameKeyPath: sectionNameKeyPath)
        }

        guard let schema = Element.sharedSchema() else {
            throw ResultsControllerError.noSchema(elementType: Element.self)
        }
        guard let property = schema[sectionNameKeyPath] else {
            throw ResultsControllerError.invalidSchema(elementType: Element.self,
                                                       sectionNameKeyPath: sectionNameKeyPath)
        }
        switch property.type {
        case .bool where Section.self is Bool.Type:
            break
        case .int where Section.self is Int.Type,
             .int where Section.self is Int8.Type,
             .int where Section.self is Int16.Type,
             .int where Section.self is Int32.Type,
             .int where Section.self is Int64.Type:
            break
        case .float where Section.self is Float.Type:
            break
        case .double where Section.self is Double.Type:
            break
        case .string where Section.self is String.Type:
            break
        case .date where Section.self is Date.Type:
            break
        case .data where Section.self is Data.Type:
            break
        default:
            throw ResultsControllerError.propertyTypeMismatch(propertyType: Section.self,
                                                              expectedPropertyType: property.type)
        }
    }

    public func start() {
        setup()
    }

    //MARK: Search
    public var searchDelay: TimeInterval = 0.2

    public var searchPredicate: NSPredicate? {
        didSet {
            precondition(Thread.current == Thread.main, "\(String(describing: self))'s searchPredicate must only be changed from the main thread.")
            guard searchPredicate != oldValue else { return }

            searchTimer = BLTimer.scheduleTimer(withTimeInterval: searchDelay,
                                                repeats: false)
            { [weak self] (timer) in
                guard timer.isValid else { return }
                self?.searchTimer = nil
                self?.setup()
            }
        }
    }

    //MARK: - Private Interface
    fileprivate var backgroundRealm: BackgroundRealm!
    fileprivate var realmChangeNotificationToken: NotificationToken!

    fileprivate var sections = OrderedDictionary<Section, Set<Int>>()
    fileprivate var sectionIndexTitles: [String]?

    //MARK: Search
    private var searchTimer: BLTimer? {
        didSet {
            oldValue?.invalidate()
        }
    }
}


//MARK: - RESULTS CONTROLLER's MAIN INTERFACE
public extension ResultsController
{
    func numberOfSections() -> Int {
        return sections.count
    }

    func section(at index: Int) -> Section {
        guard let key = sections.key(at: index) else { fatalError("Section name not found for index \(index)") }
        return key
    }

    func indexOf(section: Section) -> Int? {
        return sections.indexOf(key: section)
    }

    func numberOfItems(in section: Int) -> Int {
        guard let set = sections[section] else { fatalError("Items not found for section at index \(section)") }
        return set.count
    }

    func item(at indexPath: IndexPath) -> Element? {
        precondition(Thread.current == Thread.main, "Trying to access a \(String(describing: self)) object from outside of the main thread")

        guard let key = sections.key(at: indexPath.section) else {
            fatalError("Section name not found for index \(index)")
        }

        return objects.filter("%K == %@", sectionNameKeyPath, key)[indexPath.item]
    }

    func indexTitles() -> [String]? {
        return sectionIndexTitles
    }

    func indexPath(forIndexTitle indexTitle: String) -> IndexPath {
        precondition(sectionIndexTitles != nil,
                     "Trying to access a \(String(describing: self)) indexTitle, but no `setFormatSectionIndexTitleCallback` has been set.")
        guard let section = sectionIndexTitles!.index(of: indexTitle) else {
            return IndexPath(item: 0, section: 0)
        }
        return IndexPath(item: 0, section: section)
    }
}


//MARK: - SETUP
fileprivate extension ResultsController
{
    func setup() {
        let className = String(describing: self)

        let predicates = self.allPredicates
        let sortDescriptors = self.sortDescriptors

        realmChangeNotificationToken = nil
        resetSections()

        backgroundRealm = BackgroundRealm(configuration: realm.configuration) { [weak self] (realm, error) in
            assert(error == nil, "\(className) error: \(error!)")
            guard let realm = realm else { return }

            let results = realm
                .objects(Element.self)
                .applying(predicates: predicates,
                          sortDescriptors: sortDescriptors)

            self?.realmChangeNotificationToken = results.observe { (change) in
                switch change {
                case .error(let error):
                    assertionFailure("\(className) error: \(error)")
                case .initial(let collection):
                    self?.processInitialLoad(collection)
                case .update(let collection, let deletions, let insertions, let modifications):
                    self?.processUpdate(collection,
                                        insertions: insertions,
                                        deletions: deletions,
                                        modifications: modifications)
                }
            }
        }
    }

    //MARK: Search
    var allPredicates: [NSPredicate] {
        var result = predicates.map { $0 }
        if let searchPredicate = searchPredicate {
            result.append(searchPredicate)
        }
        return result
    }
}


//MARK: - AUX
//MARK: Notifying the delegate
fileprivate extension ResultsController
{
    func notifyReload() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let callback = strongSelf._changeCallback else { return }
            callback(.reload(controller: strongSelf))
        }
    }

    func notifySectionChange(_ insertedSections: [IndexSet],
                             _ deletedSections: [IndexSet])
    {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let callback = strongSelf._changeCallback else { return }
            callback(.sectionUpdate(controller: strongSelf,
                                    insertedSections: insertedSections,
                                    deletedSections: deletedSections))
        }
    }

    func notifyRowChange(_ insertedItems: [IndexPath],
                         _ deletedItems: [IndexPath],
                         _ updatedItems: [IndexPath])
    {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let callback = strongSelf._changeCallback else { return }
            callback(.rowUpdate(controller: strongSelf,
                                insertedItems: insertedItems,
                                deletedItems: deletedItems,
                                updatedItems: updatedItems))
        }
    }
}

//MARK: Processing changes to the data model
fileprivate extension ResultsController
{
    //MARK: Sections
    private func shouldReload(results: Results<Element>) -> Bool {
        switch (sections.isEmpty, results.isEmpty) {
        case (true, false),
             (false, true),
             (true, true):
            return true
        case (false, false):
            return false
        }
    }

    private func resetSections() {
        sections = OrderedDictionary<Section, Set<Int>>()
        sectionIndexTitles = nil
    }

    func processInitialLoad(_ results: Results<Element>)
    {
        updateSections(results: results)
        notifyReload()
    }

    private func updateSections(results: Results<Element>)
    {
        resetSections()
        results.enumerated().forEach { (offset, element) in
            guard let section = element.value(forKeyPath: sectionNameKeyPath) as? Section else { return }
            self.sections.updateValue(for: section) { (existingSet) -> Set<Int> in
                var result = existingSet ?? Set()
                result.insert(offset)
                return result
            }
        }
        var titles = sections.compactMap {
            return _formatSectionIndexTitleCallback?($0.key, self)
        }
        _sortSectionIndexTitlesCallback?(&titles, self)
        if titles.isEmpty == false {
            sectionIndexTitles = titles
        } else {
            sectionIndexTitles = nil
        }
    }

    //MARK: Everything else
    private enum ProcessType {
        case insertion, deletion, update
    }

    func processUpdate(_ results: Results<Element>,
                       insertions: [Int],
                       deletions: [Int],
                       modifications: [Int])
    {
        guard !shouldReload(results: results) else {
            processInitialLoad(results)
            return
        }

        let oldSections = sections
        updateSections(results: results)

        let insertedSections = sections.subtracting(oldSections)
        let deletedSections = oldSections.subtracting(sections)

        func makeIndexPaths(processType: ProcessType) -> [IndexPath] {
            var filteredItems: [Int]
            switch processType {
            case .insertion:
                filteredItems = insertions.filter { index in
                    return !insertedSections.contains(where: { $0.value.contains(index) })
                }
            case .deletion:
                filteredItems = deletions.filter { index in
                    return !deletedSections.contains(where: { $0.value.contains(index) })
                }
            case .update:
                filteredItems = modifications
            }

            var indexPaths = [IndexPath]()
            let sections: OrderedDictionary<Section, Set<Int>>
            switch processType {
            case .insertion, .update:
                sections = self.sections
            case .deletion:
                sections = oldSections
            }

            var sectionCountSoFar = 0
            func currentCount() -> Int {
                return sectionCountSoFar
            }
            var currentSection: OrderedDictionary<Section, Set<Int>>.Iterator? {
                didSet {
                    guard currentSection != nil else { return }
                    guard currentSection?.index != oldValue?.index else { return }
                    sectionCountSoFar += oldValue?.value.count ?? 0
                }
            }

            sections.loop { iterator in
                guard filteredItems.isEmpty == false else { return false }

                currentSection = iterator

                filteredItems = filteredItems.filter { (item) -> Bool in
                    if iterator.value.contains(item) {
                        indexPaths.append(IndexPath(item: item - currentCount(), section: iterator.index))
                        return false
                    }
                    return true
                }

                return filteredItems.isEmpty == false
            }

            return indexPaths
        }
        let insertedItems = makeIndexPaths(processType: .insertion)
        let deletedItems = makeIndexPaths(processType: .deletion)
        let updatedItems = makeIndexPaths(processType: .update)

        if !insertedSections.isEmpty || !deletedSections.isEmpty {
            let insertedSectionsIndexSet = insertedSections.map { (index, _, _) in IndexSet(integer: index) }
            let deletedSectionsIndexSet = deletedSections.map { (index, _, _) in IndexSet(integer: index) }
            notifySectionChange(insertedSectionsIndexSet,
                                deletedSectionsIndexSet)
        }

        if !insertedItems.isEmpty || !deletedItems.isEmpty || !updatedItems.isEmpty {
            notifyRowChange(insertedItems,
                            deletedItems,
                            updatedItems)
        }
    }
}
