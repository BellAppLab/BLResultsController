import Foundation
import RealmSwift
import protocol BLResultsController.ResultsControllerElement


public enum Priority: Int {
    case low
    case `default`
    case high
}
#if swift(>=4.2)
extension Priority: CaseIterable {}
#else
extension Priority: Int {
    static var allCases: [Priority] {
        return [
            .low,
            .default,
            .high
        ]
    }
}
#endif
extension Priority: Comparable {
    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}


public extension Priority {
    static var sortedCases: [Priority] {
        return allCases.sorted()
    }

    var opposite: Priority {
        switch self {
        case .default:
            return .default
        case .low:
            return .high
        case .high:
            return .low
        }
    }

    var title: String {
        switch self {
        case .high:
            return "High"
        case .default:
            return "Normal"
        case .low:
            return "Low"
        }
    }

    var letters: [String] {
        let result = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "X", "Z"]
        print("NUMBER OF LETTERS: \(result.count)")
        return result
    }

    func makeAllTodos() -> [Todo] {
        return letters.map {
            let todo = Todo()
            todo.priority = self
            todo.letter = $0
            return todo
        }
    }
}


@objcMembers
public final class Todo: Object, ResultsControllerElement
{
    dynamic var letter: String = ""
    dynamic var extraInfo: String = UUID().uuidString

    public dynamic var resultsControllerId: String = UUID().uuidString

    var text: String {
        return "Fix Thing \(letter)"
    }

    @objc
    private dynamic var _priority: Int = Priority.default.rawValue
    
    var priority: Priority {
        get {
            return Priority(rawValue: _priority)!
        }
        set {
            _priority = newValue.rawValue
        }
    }
}
