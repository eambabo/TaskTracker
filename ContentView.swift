import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView(showCompleted: false)
                .tabItem {
                    Label("To Do", systemImage: "checklist")
                }
            
            TaskListView(showCompleted: true)
                .tabItem {
                    Label("Done", systemImage: "checkmark.circle")
                }
        }
    }
}
