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
import BackgroundRealm


//MARK: - RESULTS CONTROLLER
public final class ResultsController<Section: Hashable, Element: Object>
{
    //MARK: - Public Interface
    public let predicates: [NSPredicate]
    public let sortDescriptors: [SortDescriptor]
    public let sectionNameKeyPath: String
    public let realm: Realm

    public var objects: Results<Element> {
        return realm
            .objects(Element.self)
            .applying(predicates: allPredicates,
                      sortDescriptors: sortDescriptors)
    }

    public weak var delegate: ResultsControllerDelegate?
    public weak var sectionTitleFormatter: ResultsControllerSectionTitleFormatter?

    public init(realm: Realm,
                predicates: [NSPredicate] = [],
                sectionNameKeyPath: String,
                sortDescriptors: [SortDescriptor],
                delegate: ResultsControllerDelegate)
    {
        self.realm = realm
        self.predicates = predicates
        self.sortDescriptors = sortDescriptors
        self.sectionNameKeyPath = sectionNameKeyPath

        precondition(Thread.current == Thread.main, "\(String(describing: self)) must only be instantiated from the main thread.")
        precondition(!sortDescriptors.isEmpty, "\(String(describing: self)) must have at least one sort descriptor.")
        precondition(!sectionNameKeyPath.isEmpty, "\(String(describing: self)) cannot be instatiated with an empty section name key path.")

        precondition(sortDescriptors.first!.keyPath == sectionNameKeyPath, "A \(String(describing: self))'s sectionNameKeyPath must be equal to the first sort descriptor's keyPath.")

        self.delegate = delegate

        setup()
    }

    //MARK: Search
    public var searchPredicate: NSPredicate? {
        didSet {
            precondition(Thread.current == Thread.main, "\(String(describing: self))'s searchPredicate must only be changed from the main thread.")
            guard searchPredicate != oldValue else { return }

            searchTimer = nil
            searchTimer = BLTimer.scheduleTimer(withTimeInterval: 0.2,
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
    fileprivate var sectionTitles: [String]?

    //MARK: Search
    private var searchTimer: BLTimer?
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

        return objects.filter("%K == %@", sectionNameKeyPath, key)[indexPath.row]
    }

    func indexTitles() -> [String]? {
        return sectionTitles
    }

    func indexPath(forIndexTitle indexTitle: String) -> IndexPath {
        precondition(sectionTitles != nil,
                     "Trying to access a \(String(describing: self)) indexTitle, but no \(String(describing: ResultsControllerSectionTitleFormatter.self)) has been set.")
        guard let section = sectionTitles!.index(of: indexTitle) else { return IndexPath(row: 0, section: 0) }
        return IndexPath(row: 0, section: section)
    }
}


//MARK: - SETUP
fileprivate extension ResultsController
{
    func resetSections() {
        sections = OrderedDictionary<Section, Set<Int>>()
        sectionTitles = [String]()
    }

    func setup() {
        let className = String(describing: self)

        let predicates = self.allPredicates
        let sortDescriptors = self.sortDescriptors

        realmChangeNotificationToken = nil
        resetSections()

        backgroundRealm = BackgroundRealm(configuration: realm.configuration) { [weak self] (realm, error) in
            assert(error == nil, "\(className) error: \(error!)")

            let results = realm!
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
    func notifyDelegate(_ block: @escaping (ResultsControllerDelegate, ResultsController) -> Void) {
        guard let delegate = self.delegate else { return }
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            block(delegate, strongSelf)
        }
    }
}

//MARK: Processing changes to the data model
fileprivate extension ResultsController
{
    //MARK: Sections
    private func shouldResetSections(results: Results<Element>) -> Bool {
        switch (sections.isEmpty, results.isEmpty) {
        case (true, false),
             (false, true),
             (true, true):
            return true
        case (false, false):
            return false
        }
    }

    func processInitialLoad(_ results: Results<Element>)
    {
        if shouldResetSections(results: results) {
            resetSections()
        } else {
            updateSections(results: results,
                           sectionNameKeyPath: sectionNameKeyPath)
        }

        notifyDelegate {
            $0.resultsControllerDidReloadData($1)
        }
    }

    private func updateSections(results: Results<Element>,
                                sectionNameKeyPath: String)
    {
        results.enumerated().forEach { (offset, element) in
            guard let section = element.value(forKeyPath: sectionNameKeyPath) as? Section else { return }
            self.sections.updateValue(for: section) { (existingSet) -> Set<Int> in
                var result = existingSet ?? Set()
                result.insert(offset)
                return result
            }
        }
        if let formatter = sectionTitleFormatter {
            let titles = sections.map {
                return formatter.formatSectionTitle(for: $0.key,
                                                    in: self)
            }
            sectionTitles = formatter.sortSectionTitles(titles,
                                                        for: self)
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
        guard !shouldResetSections(results: results) else {
            resetSections()
            notifyDelegate {
                $0.resultsControllerDidReloadData($1)
            }
            return
        }

        let oldSections = sections
        updateSections(results: results,
                       sectionNameKeyPath: sectionNameKeyPath)

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

            var results = [IndexPath]()
            var countSoFar = 0

            let sections: OrderedDictionary<Section, Set<Int>>
            switch processType {
            case .insertion, .update:
                sections = self.sections
            case .deletion:
                sections = oldSections
            }

            var itemIndex = 0
            sections.loop {
                guard filteredItems.count > itemIndex else { return false }
                let first = filteredItems[itemIndex]

                if $0.value.contains(first) {
                    results.append(IndexPath(row: countSoFar - first, section: $0.index))
                }

                itemIndex += 1
                countSoFar += $0.value.count

                return !filteredItems.isEmpty
            }

            return results
        }
        let insertedItems = makeIndexPaths(processType: .insertion)
        let deletedItems = makeIndexPaths(processType: .deletion)
        let updatedItems = makeIndexPaths(processType: .update)

        if !insertedSections.isEmpty || !deletedSections.isEmpty {
            let insertedSectionsIndexSet = insertedSections.map { (index, _, _) in IndexSet(integer: index) }
            let deletedSectionsIndexSet = deletedSections.map { (index, _, _) in IndexSet(integer: index) }
            notifyDelegate {
                $0.resultsController($1,
                                     didInsertSections: insertedSectionsIndexSet,
                                     andDeleteSections: deletedSectionsIndexSet)
            }
        }

        if !insertedItems.isEmpty || !deletedItems.isEmpty || !updatedItems.isEmpty {
            notifyDelegate {
                $0.resultsController($1,
                                     didInsertItems: insertedItems,
                                     deleteItems: deletedItems,
                                     andUpdateItems: updatedItems)
            }
        }
    }
}
