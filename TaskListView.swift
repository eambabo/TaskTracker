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
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasks[index])
            }
        }
    }
}
