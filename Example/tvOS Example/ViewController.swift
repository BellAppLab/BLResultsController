import UIKit
import RealmSwift
import BLResultsController


class ViewController: UITableViewController
{
    let controller: ResultsController<Int, Todo> = {
        do {
            return try ResultsController(
                realm: realm,
                sectionNameKeyPath: "_priority",
                sortDescriptors: [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false),
                    SortDescriptor(keyPath: "letter",
                                   ascending: true)
                ]
            )
        } catch {
            assertionFailure("\(error)")
            abort()
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        controller.setChangeCallback { [weak self] (_) in
            self?.tableView.reloadData()
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
            fatalError()
        }
        cell.textLabel?.text = controller.item(at: indexPath)?.text
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String?
    {
        guard let section = controller.section(at: section) else { return nil }
        guard let priority = Priority(rawValue: section) else { return nil }
        return "\(priority.title) priority"
    }
}
