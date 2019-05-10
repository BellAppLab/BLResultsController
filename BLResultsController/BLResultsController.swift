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
#elseif os(macOS)
import AppKit
#endif

#if canImport(BackgroundRealm)
import BackgroundRealm
#endif

#if canImport(Differ)
import Differ
#endif


//MARK: - RESULTS CONTROLLER
/**
 A `ResultsController` takes a `Realm.Results` and divides its objects into sections based on the `sectionNameKeyPath` and the first `sortDescriptor`. It then calculates the relative positions of those objects and generates section indices and `IndexPath`s that are ready to be passed to `UITableView`s and `UICollectionView`s.

 As with `Realm.Results`, the `ResultsController` is a live, auto-updating container that will keep notifying you of changes in the dataset for as long as you hold a strong reference to it. You register to receive those changes by calling `setChangeCallback(_:)` on your controller.

 - note:
    Changes to the underlying dataset are calculated on a background queue, therefore the UI thread is not impacted by the `ResultsController`'s overhead.

 - warning:
    As with `Realm` itself, the `ResultsController` is **not** thread-safe. You should only call its methods from the main thread.

 ## Example

 ```swift
 class ViewController: UITableViewController {
     let controller: ResultsController<<#SectionType#>, <#ElementType#>> = {
         do {
             let realm = <#instantiate your realm#>
             let keyPath = <#the key path to your Element's property to be used as a section#>
             return try ResultsController(
                 realm: realm,
                 sectionNameKeyPath: keyPath,
                 sortDescriptors: [
                     SortDescriptor(keyPath: keyPath)
                 ]
             )
         } catch {
             assertionFailure("\(error)")
             //do something about the error
         }
     }()

     override func viewDidLoad() {
         super.viewDidLoad()

         controller.setChangeCallback { [weak self] (_) in
             <#code#>
         }

         controller.start()
     }

     override func numberOfSections(in tableView: UITableView) -> Int {
         return controller.numberOfSections()
     }

     override func tableView(_ tableView: UITableView,
                             numberOfRowsInSection section: Int) -> Int
     {
         return controller.numberOfItems(in: section)
     }

     override func tableView(_ tableView: UITableView,
                             cellForRowAt indexPath: IndexPath) -> UITableViewCell
     {
         guard let cell = tableView.dequeueReusableCell(withIdentifier: <#identifier#>) else {
             fatalError("Did we configure the cell correctly on IB?")
         }
         <#code#>
         return cell
     }
 }
 ```

 ## See Also
 - `start()`
 - `setChangeCallback(_:)`
 */
public final class ResultsController<Section: ResultsControllerSection, Element: ResultsControllerElement>
{
    //MARK: - Public Interface
    /// The main realm from which the `ResultsController` will fetch its data.
    public let realm: Realm

    /// The `NSPredicate`s currently in use by this `ResultsController`.
    public private(set) var predicates: [NSPredicate]
    /// The `SortDescriptor`s currently in use by this `ResultsController`.
    public private(set) var sortDescriptors: [SortDescriptor]
    /// The path to the property used to calculate sections in this `ResultsController`.
    public private(set) var sectionNameKeyPath: String

    /**
     Call this method to change the `ResultsController`'s properties without having to instantiate a new one.

     Calling this method will cause the `ResultsController` to reload all its data.

     - parameters:
         - predicates: An array of `NSPredicate` to be used by the `ResultsController`, or `nil` if you don't want to change them.
         - sortDescriptors: An array of `SortDescriptor` to be used by the `ResultsController`, or `nil` if you don't want to change them.
         - sectionNameKeyPath: The key path to the `ResultsController.Element`'s property to be used as a section, or `nil` if you don't want to change it.

     - note:
        Passing `nil` to all parameters in this method is equivalent to calling `reload()` on the `ResultsController`.

     - warning:
        This method must be called from the main thread.

     - throws:
         - See `init(realm:predicates:sectionNameKeyPath:sortDescriptors:)`

     ## See Also:
     - `start()`
     - `reload()`
     */
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

    /**
     This is the `Results<Element>` returned from applying this controller's `predicates` and `sortDescriptors` to the `realm` passed on initialisation.

     The objects in this collection are **not** separated into sections. To get those, use `item(at:)`.

     - warning: This **must** be called from the main thread.
     */
    public var objects: Results<Element> {
        return realm
            .objects(Element.self)
            .applying(predicates: allPredicates,
                      sortDescriptors: sortDescriptors)
    }

    //MARK: Callbacks
    /// The callback a `ResultsController` invokes when the underlying dataset changes.
    public enum ChangeCallback {
        /// Called when the whole dataset has changed.
        case reload(controller: ResultsController<Section, Element>)
        /// Called when sections have been added or removed from the `ResultsController`.
        case sectionUpdate(controller: ResultsController<Section, Element>, insertedSections: [IndexSet], deletedSections: [IndexSet])
        /// Called when items have been inserted, deleted or updated in the underlying dataset.
        case rowUpdate(controller: ResultsController<Section, Element>, insertedItems: [IndexPath], deletedItems: [IndexPath], updatedItems: [IndexPath])
    }

    fileprivate var _changeCallback: ((ResultsController.ChangeCallback) -> Void)?
    /**
     Sets the callback to be invoked by this `ResultsController` when its underlying dataset changes.

     A typical implementation of this callback in a table view controller would look like this:

     ```
     override func viewDidLoad() {
         super.viewDidLoad()

         controller.setChangeCallback { [weak self] change in
             switch change {
             case .reload(_):
                 self?.tableView.reloadData()
             case .sectionUpdate(_, let insertedSections, let deletedSections):
                 self?.tableView.beginUpdates()
                 insertedSections.forEach { self?.tableView.insertSections($0, with: .automatic) }
                 deletedSections.forEach { self?.tableView.deleteSections($0, with: .automatic) }
                 self?.tableView.endUpdates()
             case .rowUpdate(_, let insertedItems, let deletedItems, let updatedItems):
                 self?.tableView.beginUpdates()
                 self?.tableView.insertRows(at: insertedItems, with: .automatic)
                 self?.tableView.deleteRows(at: deletedItems, with: .automatic)
                 self?.tableView.reloadRows(at: updatedItems, with: .automatic)
                 self?.tableView.endUpdates()
             }
         }

         controller.start()
     }
     ```

     - parameters:
         - change: The `ChangeCallback` to be invoked.
     */
    public func setChangeCallback(_ change: ((ResultsController.ChangeCallback) -> Void)?) {
        _changeCallback = change
    }

    /**
     The callback that's invoked to produce section index titles based on this `ResultsController`'s newly calculated sections.

     - parameters:
         - section: The `Section` that is being converted to a section title index.
         - controller: The `ResultsController` invoking this callback.

     - returns: The section index title for this `Section`.

     ## See Also:
     - `setFormatSectionIndexTitleCallback(_:)`
     */
    public typealias SectionIndexTitleCallback = (_ section: Section, _ controller: ResultsController<Section, Element>) -> String
    fileprivate var _formatSectionIndexTitleCallback: ResultsController.SectionIndexTitleCallback?
    /**
     Set the callback that's invoked to produce section index titles based on this `ResultsController`'s newly calculated sections.

     The `UITableViewDataSource` protocol defines the optional `sectionIndexTitles(for:)` and `tableView(_:sectionForSectionIndexTitle:at:)` methods as ways to populate a `UITableView`'s section index titles. The most common use case of this are alphabetical lists whose sections are the first letters of each item (think of the Contacts app and that little list of "A", "B", "C", etc. at the right-hand side).

     This callback is how you supply the `ResultsController` with a way to convert a `Section` into its index title.

     ## Example:

     ```
     controller.setFormatSectionIndexTitleCallback { (section, _) -> String in
         //suppose your `Section` is an `Int`
         return "\(section)"
     }
     ```

     - note: This callback is invoked on a **background thread**.

     - parameters:
         - callback: A `ResultsController.SectionIndexTitleCallback`.
     */
    public func setFormatSectionIndexTitleCallback(_ callback: ResultsController.SectionIndexTitleCallback?) {
        _formatSectionIndexTitleCallback = callback
    }

    /**
     The callback that's invoked to sort section index titles based on this `ResultsController`'s newly calculated sections.

     - parameters:
         - indexTitles: The calculated index titles.
         - controller: The `ResultsController` invoking this callback.

     ## See Also:
     - `setSortSectionIndexTitles(_:)`
     */
    public typealias SortSectionIndexTitlesCallback = (_ indexTitles: inout [String], _ controller: ResultsController<Section, Element>) -> Void
    fileprivate var _sortSectionIndexTitlesCallback: ResultsController.SortSectionIndexTitlesCallback?
    /**
     Set the callback that's invoked to sort section index titles based on this `ResultsController`'s newly calculated sections.

     This callback is a way for you to sort the newly calculated section index titles. If no callback is set, they'll be supplied in the order that the sections occur in the dataset.

     ## Example:

     ```
     controller.setSortSectionIndexTitles { (sections, _) in
         //suppose your `Section` is an `Int`
         sections.sort(by: { $0 < $1 })
     }
     ```

     - note: This callback is invoked on a **background thread**.

     - parameters:
         - callback: A `ResultsController.SortSectionIndexTitlesCallback`.
     */
    public func setSortSectionIndexTitles(_ callback: ResultsController.SortSectionIndexTitlesCallback?) {
        _sortSectionIndexTitlesCallback = callback
    }

    /**
     Creates a new `ResultsController` with the given parameters.

     After instantiating a `ResultsController`, you **must** call `start()` for it to begin doing its magic.

     - parameters:
         - realm: A `Realm` instance you have created on the main thread.
         - predicates: The `NSPredicate`s to be applied to `realm` and to the background realm this controller will create.
         - sectionNameKeyPath: The key path to a property of your `Realm.Object` subclass to be used as a section divider. See `ResultsControllerSection` for more info.
         - sortDescriptors: An array of `SortDescriptor`s to be applied to `realm` and to the background realm this controller will create.

     - throws:
         - `ResultsControllerError.noSortDescriptors`
             - if `sortDescriptors` is empty
         - `ResultsControllerError.noSectionNameKeyPath`
             - if `sectionNameKeyPath` is empty
         - `ResultsControllerError.sortDescriptorMismatch`
             - if the first `SortDescriptor`'s key path is different than `sectionNameKeyPath`
         - `ResultsControllerError.noSchema`
             - if `Element.sharedSchema()` returns `nil`
             - this should never happen, but you never know...
         - `ResultsControllerError.invalidSchema`
             - if `sectionNameKeyPath` is not a valid key path of `Element`
             - in other words, if there is no property in your object that can be accessed via `sectionNameKeyPath`
         - `ResultsControllerError.propertyTypeMismatch`
             - if the property returned by your `Element`'s `sectionNameKeyPath` is not of the same type as this controller's `Section`

     - note: You **must** call this method from the main thread.

     ## See Also:
     - [BackgroundRealm](https://github.com/BellAppLab/BackgroundRealm)
     - `ResultsControllerError`
     */
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

    /**
     Starts the `ResultsController` and call the `changeCallback` with the `reload` option.

     By default, the `ResultsController` does **not** start calculating sections once you instantiate it. Thus you must call `start()` after creating one. This is to avoid the overhead of calculating all sections before it is actually needed.

     ## See Also:
     - `init(realm:predicates:sectionNameKeyPath:sortDescriptors:)`
     */
    public func start() {
        setup()
    }

    /**
     Recalculates all sections in the `ResultsController` and call the `changeCallback` with the `reload` option.

     You typically don't need to call this method, but it's here for convenience.

     ## See Also:
     - `init(realm:predicates:sectionNameKeyPath:sortDescriptors:)`
     - `start()`
     */
    public func reload() {
        setup()
    }

    //MARK: Search
    /**
     Appends an `NSPredicate` to this controller's `predicates`.

     Typically, you create a predicated with user-generated input like this:

     ```
     extension <#YourViewControllerSubclass#>: UISearchBarDelegate {
         func searchBar(_ searchBar: UISearchBar,
                        textDidChange searchText: String)
         {
             guard searchText.isEmpty == false else {
                 controller.searchPredicate = nil
                 return
             }
             controller.searchPredicate = NSPredicate(format: "%K CONTAINS[c] %@", <#name of the property in your object#>, searchText)
         }
     }
     ```

     - warning: This property must be accesed from the **main thread**.

     - note: Setting this property will cause the `ResultsController` to reload all its data.

     ## See Also:
     - `searchDelay`
     */
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

    /**
     When a `searchPredicate` is set, the `ResultsController` waits a little bit before applying it.

     This is done so the whole underlying data isn't reloaded unecessarily while the user is still typing. The default value is 0.4 seconds.

     - note: If there is delay alreay in progress, setting this property will **not** adjust it.

     ## See Also:
     - `searchPredicate`
     */
    public var searchDelay: TimeInterval = 0.4

    //MARK: - Private Interface
    fileprivate var backgroundRealm: BackgroundRealm!
    fileprivate var realmChangeNotificationToken: NotificationToken!

    fileprivate var elements: [InternalElement<Section>] = []
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
    /**
     The number of sections in this `ResultsController`.

     You pass this value to `numberOfSections(in:)`.

     - note: This method can be called from any thread.

     - complexity: O(1)
     */
    func numberOfSections() -> Int {
        return elements.count
    }

    /**
     The `Section` at a particular index.

     Useful to populate section headers, such when `tableView(_:titleForHeaderInSection:)` is called.

     - parameters:
         - index: The index for which you want the equivalent `Section`.

     - returns: The `Section` at `index`.

     - note: This method can be called from any thread.

     - complexity: O(1)
     */
    func section(at index: Int) -> Section? {
        return elements[index].key
    }

    /**
     The index of a particular `Section, or `nil` if none is found.

     - parameters:
         - section: The `Section` for which you want the equivalent index.

     - returns: The index of `Section`.

     - note: This method can be called from any thread.

     - complexity: O(n)
     */
    func indexOf(section: Section) -> Int? {
        return elements.enumerated().first(where: { $0.element.key == section })?.offset
    }

    /**
     The number of items in a given section of this `ResultsController`.

     You pass this value to `tableView(_:numberOfRowsInSection:)` or `collectionView(_:numberOfItemsInSection:)`.

     - parameters:
         - section: The `Section` for which you want the `Element` count.

     - returns: The number of `Element`s.

     - note: This method can be called from any thread.

     - complexity: O(1)
     */
    func numberOfItems(in sectionIndex: Int) -> Int {
        guard elements.isEmpty == false else { return 0 }
        return elements[sectionIndex].items.count
    }

    /**
     Get the `Element` at a given `IndexPath`.

     You typically use this method in `tableView(_:cellForRowAt:)` and/or the `UICollectionView` equivalent.

     - parameters:
         - indexPath: The `IndexPath` for which you want to retrieve an `Element`.

     - returns: The `Element` at the given `IndexPath` or `nil` if none has been found.

     - note: This method can only be called from the **main thread**.

     - complexity: Whatever the complexity of calling `realm.objects(Element.self).filter(...)[indexPath.item]` is.
     */
    func item(at indexPath: IndexPath) -> Element? {
        precondition(Thread.current == Thread.main, "Trying to access a \(String(describing: self)) object from outside of the main thread")
        precondition(indexPath.section > -1, "Index path's (\(indexPath)) section should be greated than zero")

        guard indexPath.section < elements.count else {
            return nil
        }

        let element = elements[indexPath.section]

        guard element.items.isEmpty == false else {
            return nil
        }

        return objects.filter("%K == %@", sectionNameKeyPath, element.key)[indexPath.item]
    }

    /**
     Get the section index titles this `ResultsController` has computed.

     This method only returns the index titles if a `SectionIndexTitleCallback` has been set. Otherwise, `nil`.

     - note: This method can be called from any thread.

     ## See Also
     - `setChangeCallback(_:)`
     */
    func indexTitles() -> [String]? {
        return sectionIndexTitles
    }

    /**
     Get the `IndexPath` for the first item in the section with the given index title.

     You typically pass the result of this method to `tableView(_:sectionForSectionIndexTitle:at:)`.

     - warning: Only call this method if you have supplied a `SectionIndexTitleCallback` to this `ResultsController`. Calling this method without having supplied a `SectionIndexTitleCallback` is a programmer error and will crash your app.

     - parameters:
         - indexTitle: The index title for which you want to retrieve an `IndexPath`.

     - returns: The `IndexPath` for the first item in the section with the given index title.

     - note: This method can be called from any thread.

     ## See Also
     - `setChangeCallback(_:)`
     */
    func indexPath(forIndexTitle indexTitle: String) -> IndexPath {
        precondition(sectionIndexTitles != nil,
                     "Trying to access a \(String(describing: self)) indexTitle, but no `setFormatSectionIndexTitleCallback` has been set.")
        guard let section = sectionIndexTitles!.firstIndex(of: indexTitle) else {
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
        reset()

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
        DispatchQueue.main.sync { [weak self] in
            guard let strongSelf = self, let callback = strongSelf._changeCallback else { return }
            callback(.reload(controller: strongSelf))
        }
    }

    func notifySectionChange(_ insertedSections: [IndexSet],
                             _ deletedSections: [IndexSet])
    {
        DispatchQueue.main.sync { [weak self] in
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
        DispatchQueue.main.sync { [weak self] in
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
        switch (elements.isEmpty, results.isEmpty) {
        case (true, false),
             (false, true),
             (true, true):
            return true
        case (false, false):
            return false
        }
    }

    private func reset() {
        elements = []
        sectionIndexTitles = nil
    }

    func processInitialLoad(_ results: Results<Element>) {
        elements = generateElements(results: results)
        notifyReload()
    }

    private func generateElements(results: Results<Element>) -> [InternalElement<Section>]
    {
        var newElements = [InternalElement<Section>]()
        var currentElement: InternalElement<Section>?
        results.enumerated().forEach { (offset, result) in
            guard let section = result.value(forKeyPath: sectionNameKeyPath) as? Section else { return }
            if let element = currentElement {
                if element.key == section {
                    currentElement?.insertElement(result)
                } else {
                    newElements.append(element)
                    currentElement = nil
                }
            }
            if currentElement == nil {
                currentElement = InternalElement(element: result,
                                                 key: section)
            }
        }
        if let element = currentElement {
            newElements.append(element)
        }
        var titles = newElements.compactMap {
            return _formatSectionIndexTitleCallback?($0.key, self)
        }
        _sortSectionIndexTitlesCallback?(&titles, self)
        if titles.isEmpty == false {
            sectionIndexTitles = titles
        } else {
            sectionIndexTitles = nil
        }
        return newElements
    }

    //MARK: Everything else
    func processUpdate(_ results: Results<Element>,
                       insertions: [Int],
                       deletions: [Int],
                       modifications: [Int])
    {
        guard shouldReload(results: results) == false else {
            processInitialLoad(results)
            return
        }

        let old = elements
        let new = generateElements(results: results)

        let diff = old.nestedExtendedDiff(to: new)
        let update = NestedBatchUpdate(diff: diff)

        elements = new

        let sectionInsertions: [IndexSet] = {
            guard new.isEmpty == false else { return [] }
            let result = update.sectionInsertions()
            guard result.isEmpty == false else { return [] }
            return [result]
        }()
        let sectionDeletions: [IndexSet] = {
            guard old.isEmpty == false else { return [] }
            let result = update.sectionDeletions()
            guard result.isEmpty == false else { return [] }
            return [result]
        }()

        if sectionInsertions.isEmpty == false ||
            sectionDeletions.isEmpty == false
        {
            notifySectionChange(sectionInsertions,
                                sectionDeletions)
        }

        let insertionIndexPaths = update.itemInsertions().filter {
            return new[$0.section].items.isEmpty == false
        }
        let deletedIndexPaths = update.itemDeletions().filter {
            return old[$0.section].items.isEmpty == false
        }
        let modifiedIndexPaths = new.indexPathsOfElements(indices: modifications).filter {
            return new[$0.section].items.isEmpty == false
        }

        if insertionIndexPaths.isEmpty == false ||
            deletedIndexPaths.isEmpty == false ||
            modifiedIndexPaths.isEmpty == false
        {
            notifyRowChange(insertionIndexPaths,
                            deletedIndexPaths,
                            modifiedIndexPaths)
        }
    }
}


private extension NestedBatchUpdate
{
    private static let includeMoves = false

    func sectionDeletions(includingMoves: Bool = NestedBatchUpdate.includeMoves) -> IndexSet {
        guard includingMoves else { return sectionDeletions }
        var result = sectionDeletions
        sectionMoves.forEach {
            result.insert($0.from)
        }
        return result
    }

    func sectionInsertions(includingMoves: Bool = NestedBatchUpdate.includeMoves) -> IndexSet {
        guard includingMoves else { return sectionInsertions }
        var result = sectionInsertions
        sectionMoves.forEach {
            result.insert($0.to)
        }
        return result
    }

    func itemDeletions(includingMoves: Bool = NestedBatchUpdate.includeMoves) -> [IndexPath] {
        guard includingMoves else { return itemDeletions }
        var result = itemDeletions
        itemMoves.forEach {
            result.append($0.from)
        }
        return result
    }

    func itemInsertions(includingMoves: Bool = NestedBatchUpdate.includeMoves) -> [IndexPath] {
        guard includingMoves else { return itemInsertions }
        var result = itemInsertions
        itemMoves.forEach {
            result.append($0.to)
        }
        return result
    }
}
