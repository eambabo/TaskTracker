import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack {
            Toggle(isOn: $task.isCompleted) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
            }
            .toggleStyle(CheckboxToggleStyle()) // Custom toggle style or standard
            
            if let dueDate = task.dueDate {
                Text(dueDate, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("P:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(task.priority.title)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color(for: task.priority))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // Helper to color code priorities and urgencies
    private func color(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    

}

// Simple Checkbox Style (Optional, standard toggle is also fine but this looks better for tasks)
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Button {
                configuration.isOn.toggle()
            } label: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(configuration.isOn ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            configuration.label
        }
    }
}
