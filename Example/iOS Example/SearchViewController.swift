import UIKit
import RealmSwift
import BLResultsController


class SearchViewController: UITableViewController
{
    //MARK: Data Model
    let controller: ResultsController<Int, Todo> = {
        do {
            return try ResultsController(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false),
                    SortDescriptor(keyPath: "letter",
                                   ascending: false)
                ]
            )
        } catch {
            assertionFailure("\(error)")
            abort()
        }
    }()

    //MARK: UI Elements
    @IBOutlet weak var searchBar: UISearchBar!

    //MARK: View Controller Life Cycle
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
}


//MARK: - UI Actions
extension SearchViewController {
    @IBAction func animateButtonPressed(_ sender: Any?) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            var indexPath = IndexPath(row: 0, section: 0)
            DispatchQueue.main.sync {
                guard let item = self.controller.item(at: indexPath) else { fatalError() }
                try! realm.write {
                    realm.delete(item)
                }
            }

            sleep(5)

            indexPath = IndexPath(row: 4, section: 0)
            DispatchQueue.main.sync {
                guard let item = self.controller.item(at: indexPath) else { fatalError() }
                try! realm.write {
                    realm.delete(item)
                }
            }

            sleep(5)

            indexPath = IndexPath(row: 3, section: 0)
            DispatchQueue.main.sync {
                guard let item = self.controller.item(at: indexPath) else { fatalError() }
                try! realm.write {
                    item.letter += "§"
                }
            }
        }
    }
}


//MARK: - Table View Data Source
extension SearchViewController {
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
            fatalError()
        }
        let item = controller.item(at: indexPath)
        cell.textLabel?.text = item?.text
        cell.detailTextLabel?.text = item?.extraInfo
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String?
    {
        guard let section = controller.section(at: section) else { return nil }
        return "\(Priority(rawValue: section)?.title ?? "") priority"
    }
}


//MARK: - Search Bar Delegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar,
                   textDidChange searchText: String)
    {
        guard searchText.isEmpty == false else {
            controller.searchPredicate = nil
            return
        }
        controller.searchPredicate = NSPredicate(format: "extraInfo CONTAINS[c] %@", searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
