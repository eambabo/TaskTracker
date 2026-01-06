import SwiftUI
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var priorityRaw: Int
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date

    @Transient
    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }


    init(title: String, priority: TaskPriority = .medium, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

enum TaskPriority: Int, Codable, Identifiable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
