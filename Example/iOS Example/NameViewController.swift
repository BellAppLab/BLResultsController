import UIKit
import RealmSwift
import BLResultsController


class NameViewController: UITableViewController
{
    //MARK: Data Model
    let controller: ResultsController<String, Todo> = {
        do {
            return try ResultsController(
                realm: realm,
                sectionNameKeyPath: "letter",
                sortDescriptors: [
                    SortDescriptor(keyPath: "letter",
                                   ascending: false),
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            )
        } catch {
            assertionFailure("\(error)")
            abort()
        }
    }()

    enum Segment: Int, CaseIterable {
        case letterDescending
        case letterAscending

        var formattedName: String {
            switch self {
            case .letterDescending:
                return "Descending"
            case .letterAscending:
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

            let sortDescriptors: [RealmSwift.SortDescriptor]
            switch currentSegment {
            case .letterDescending:
                sortDescriptors = [
                    SortDescriptor(keyPath: "letter",
                                   ascending: false),
                    SortDescriptor(keyPath: "_priority",
                                   ascending: false)
                ]
            case .letterAscending:
                sortDescriptors = [
                    SortDescriptor(keyPath: "letter",
                                   ascending: true),
                    SortDescriptor(keyPath: "_priority",
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
        segmentedControl.selectedSegmentIndex = Segment.letterDescending.rawValue

        controller.bind(to: tableView)

        controller.setFormatSectionIndexTitleCallback { (section, _) -> String in
            return section
        }

        controller.setSortSectionIndexTitles { (sections, _) in
            sections.sort(by: { $0 < $1 })
        }

        controller.start()
    }

    //MARK: UI Actions
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentSegment = Segment(rawValue: segmentedControl.selectedSegmentIndex)!
    }
}


//MARK: - Table View Data Source
extension NameViewController {
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
        cell.textLabel?.text = "\(item?.text ?? "") - Priority \(item?.priority.title ?? "")"
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String?
    {
        return controller.section(at: section)
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return controller.indexTitles()
    }

    override func tableView(_ tableView: UITableView,
                            sectionForSectionIndexTitle title: String,
                            at index: Int) -> Int
    {
        switch currentSegment {
        case .letterAscending:
            return controller.indexPath(forIndexTitle: title).section
        case .letterDescending:
            return controller.numberOfSections() - 1 - controller.indexPath(forIndexTitle: title).section
        }
    }
}
