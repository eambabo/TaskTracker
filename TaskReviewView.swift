//
//  TaskReviewView.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import SwiftData

struct TaskReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var extractedTasks: [ExtractedTask]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($extractedTasks) { $task in
                        TaskReviewRow(task: $task)
                    }
                } header: {
                    Text("Extracted Tasks")
                } footer: {
                    Text("Toggle tasks to include or exclude them. Tap to edit details.")
                }
            }
            .navigationTitle("Review Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Tasks") {
                        addSelectedTasks()
                    }
                    .disabled(!extractedTasks.contains { $0.isSelected })
                }
            }
        }
    }

    private func addSelectedTasks() {
        let selectedTasks = extractedTasks.filter { $0.isSelected }

        for task in selectedTasks {
            let newTask = TaskItem(
                title: task.title,
                priority: task.priority,
                dueDate: parseDueDate(from: task.dueDateDescription)
            )
            modelContext.insert(newTask)

            NotificationManager.shared.scheduleTaskDueDateNotification(for: newTask)
        }

        dismiss()
    }

    private func parseDueDate(from description: String?) -> Date? {
        guard let description = description?.lowercased() else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch description {
        case "today", "tonight":
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today)

        case "tomorrow", "tomorrow morning":
            return calendar.date(byAdding: .day, value: 1, to: today)

        case "tomorrow afternoon", "tomorrow evening":
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow)
            }

        case "this weekend":
            let weekday = calendar.component(.weekday, from: today)
            let daysUntilSaturday = (7 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)

        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: today)

        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: today)

        case "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday":
            let weekdayNumber = weekdayFromName(description)
            let currentWeekday = calendar.component(.weekday, from: today)
            var daysToAdd = weekdayNumber - currentWeekday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }
            return calendar.date(byAdding: .day, value: daysToAdd, to: today)

        case "by end of day", "by eod":
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: today)

        case "end of week":
            let weekday = calendar.component(.weekday, from: today)
            let daysUntilFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilFriday == 0 ? 7 : daysUntilFriday, to: today)

        case "end of month":
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) {
                return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: nextMonth))
            }

        default:
            return nil
        }

        return nil
    }

    private func weekdayFromName(_ name: String) -> Int {
        switch name.lowercased() {
        case "sunday": return 1
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        default: return 1
        }
    }
}

struct TaskReviewRow: View {
    @Binding var task: ExtractedTask
    @State private var isEditing = false

    var body: some View {
        HStack {
            Button {
                task.isSelected.toggle()
            } label: {
                Image(systemName: task.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isSelected ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Task title", text: $task.title)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(task.title)
                        .strikethrough(!task.isSelected)
                        .foregroundStyle(task.isSelected ? .primary : .secondary)
                }

                HStack(spacing: 8) {
                    Menu {
                        ForEach(TaskPriority.allCases) { priority in
                            Button {
                                task.priority = priority
                            } label: {
                                Label(priority.title, systemImage: task.priority == priority ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Text(task.priority.title)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(for: task.priority))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    if let dueDate = task.dueDateDescription {
                        Text(dueDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}
