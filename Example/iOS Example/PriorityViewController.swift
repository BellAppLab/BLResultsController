import UIKit
import RealmSwift
import BLResultsController


class PriorityViewController: UITableViewController
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

    enum Segment: Int, CaseIterable {
        case priorityDescending
        case priorityAscending

        var formattedName: String {
            switch self {
            case .priorityDescending:
                return "Descending"
            case .priorityAscending:
                return "Ascending"
            }
        }
    }

    var currentSegment: Segment {
        get {
            return Segment(rawValue: segmentedControl.selectedSegmentIndex)!
        }
        set {
            segmentedControl.selectedSegmentIndex = newValue.rawValue

            let sortDescriptors: [SortDescriptor]
            switch currentSegment {
            case .priorityDescending:
                sortDescriptors = [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false),
                    SortDescriptor(keyPath: "letter",
                                   ascending: false)
                ]
            case .priorityAscending:
                sortDescriptors = [
                    SortDescriptor(keyPath: "_priority",
                                   ascending: true),
                    SortDescriptor(keyPath: "letter",
                                   ascending: true)
                ]
            }

            do {
                try controller.change(sortDescriptors: sortDescriptors)
            } catch {
                assertionFailure("\(error)")
            }
        }
    }

    //MARK: UI Elements
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    //MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        Segment.allCases.forEach {
            segmentedControl.setTitle($0.formattedName,
                                      forSegmentAt: $0.rawValue)
        }
        segmentedControl.selectedSegmentIndex = Segment.priorityDescending.rawValue

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

    //MARK: UI Actions
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentSegment = Segment(rawValue: segmentedControl.selectedSegmentIndex)!
    }
}


//MARK: - Table View Data Source
extension PriorityViewController {
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
        return "\(Priority(rawValue: controller.section(at: section))?.title ?? "") priority"
    }
}
