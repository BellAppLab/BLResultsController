import Foundation
import RealmSwift


#if swift(>=4.2)
public enum Priority: Int, CaseIterable {
    case low
    case `default`
    case high
}
#else
public enum Priority: Int {
    static var allCases: [Priority] {
        return [
            .low,
            .default,
            .high
        ]
    }

    case low
    case `default`
    case high
}
#endif


public extension Priority {
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
            todo.text = "Fix Thing \($0)"
            return todo
        }
    }
}


@objcMembers
public final class Todo: Object
{
    dynamic var text: String = ""

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
