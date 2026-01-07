import SwiftUI
import SwiftData

enum SortOption {
    case priority
}

struct TaskListView: View {
    let showCompleted: Bool
    @State private var sortOption: SortOption = .priority
    @State private var showAddTask = false

    var body: some View {
        NavigationStack {
            FilteredTaskList(showCompleted: showCompleted, sortOption: sortOption)
                .navigationTitle(showCompleted ? "Completed" : "To Do")
                .toolbar {
                    if !showCompleted {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showAddTask = true
                            } label: {
                                Label("Add Task", systemImage: "plus")
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                Text("Priority").tag(SortOption.priority)
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showAddTask) {
                    AddTaskView()
                }
        }
    }
}

struct FilteredTaskList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    
    init(showCompleted: Bool, sortOption: SortOption) {
        let sortDescriptor: SortDescriptor<TaskItem>
        switch sortOption {
        case .priority:
            // Sort High to Low (2 -> 0)
            sortDescriptor = SortDescriptor(\TaskItem.priorityRaw, order: .reverse)
        }
        
        _tasks = Query(filter: #Predicate<TaskItem> {
            $0.isCompleted == showCompleted
        }, sort: [sortDescriptor])
    }
    
    var body: some View {
        List {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text("You don't have any tasks in this view.")
                )
            } else {
                ForEach(tasks) { task in
                    TaskRowView(task: task)
                }
                .onDelete(perform: deleteItems)
            }
        }
        .listStyle(.plain)
        .onChange(of: tasks) { _, newTasks in
            // Only refresh digests if we are viewing "To Do" items, 
            // because that represents the active tasks we care about.
            // Although, if we delete a task from "Completed", it doesn't affect digests (it was already done).
            // If we mark a task as uncompleted (from Completed view), it enters To Do.
            // So observing To Do list is best.
             NotificationManager.shared.refreshDigests(tasks: newTasks)
        }
        .onAppear {
             NotificationManager.shared.refreshDigests(tasks: tasks)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let task = tasks[index]
                NotificationManager.shared.cancelTaskNotification(for: task)
                modelContext.delete(task)
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notifyOnDueDate") private var notifyOnDueDate = false
    @AppStorage("dailyDigestEnabled") private var dailyDigestEnabled = false
    @AppStorage("weeklyDigestEnabled") private var weeklyDigestEnabled = false
    
    @Query private var tasks: [TaskItem]
    
    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            NotificationManager.shared.requestAuthorization()
                        }
                        updateDigests()
                        NotificationManager.shared.rescheduleAllTaskDueDateNotifications(tasks: tasks)
                    }
                
                if notificationsEnabled {
                    Toggle("Notify at Due Date/Time", isOn: $notifyOnDueDate)
                        .onChange(of: notifyOnDueDate) { _, _ in
                             NotificationManager.shared.rescheduleAllTaskDueDateNotifications(tasks: tasks)
                        }
                    
                    Toggle("Daily Digest (5 AM)", isOn: $dailyDigestEnabled)
                        .onChange(of: dailyDigestEnabled) { _, _ in updateDigests() }
                    
                    Toggle("Weekly Digest (Mondays 5 AM)", isOn: $weeklyDigestEnabled)
                        .onChange(of: weeklyDigestEnabled) { _, _ in updateDigests() }
                }
            }
            
            Section(footer: Text("Weekly digest shows tasks due in the coming week. If both digests are enabled, the Daily digest is skipped on Mondays.")) {
                EmptyView()
            }
        }
        .navigationTitle("Settings")
    }
    
    private func updateDigests() {
        // If master switch is off, pass false for everything or handle inside manager
        // But manager takes (daily, weekly) args.
        // If notificationsEnabled is false, we should effectively treat others as false for scheduling purposes
        // although we keep the user's preference for the toggles intact.
        
        let daily = notificationsEnabled && dailyDigestEnabled
        let weekly = notificationsEnabled && weeklyDigestEnabled
        
        NotificationManager.shared.rescheduleDigests(
            tasks: tasks,
            isDailyEnabled: daily,
            isWeeklyEnabled: weekly
        )
    }
}
