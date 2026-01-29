//
//  TaskTrackerApp.swift
//  TaskTracker
//
//  Created by Ethan Ambabo on 12/30/25.
//


import SwiftUI
import SwiftData
import UserNotifications

@main
struct TaskTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            AudioNote.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permissions
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Task Specific Notifications (Option 2)
    
    func scheduleTaskDueDateNotification(for task: TaskItem) {
        // Remove any existing notification for this task first
        cancelTaskNotification(for: task)
        
        let defaults = UserDefaults.standard
        let master = defaults.bool(forKey: "notificationsEnabled")
        let specific = defaults.bool(forKey: "notifyOnDueDate")
        
        guard master && specific else { return }
        
        guard let validDate = task.dueDate, validDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = "Your task \"\(task.title)\" is due now."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: validDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling task notification: \(error)")
            }
        }
    }
    
    func rescheduleAllTaskDueDateNotifications(tasks: [TaskItem]) {
        for task in tasks {
            scheduleTaskDueDateNotification(for: task)
        }
    }
    
    func cancelTaskNotification(for task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    // MARK: - Digest Notifications (Options 3 & 4)
    
    func rescheduleDigests(tasks: [TaskItem], isDailyEnabled: Bool, isWeeklyEnabled: Bool) {
        // Clear all existing digests first
        // We need a stable way to identify digest notifications. 
        // Let's use identifiers like "digest_daily_YYYY_MM_DD" and "digest_weekly_YYYY_MM_DD"
        
        // Remove ALL pending digests. Since we can't easily wildcard remove, 
        // we might just remove all and re-add task ones? No, that's inefficient.
        // We will track digest IDs or just remove specifically calculating the next few.
        // A simpler approach for this MVP: 
        // Use a fixed set of identifiers for the next 7 days.
        // "digest_day_0", "digest_day_1", ... "digest_day_6" offset from today.
        
        // First, cancel known potential digest IDs
        let digestIds = (0...14).flatMap { ["digest_daily_\($0)", "digest_weekly_\($0)"] }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: digestIds)
        
        guard isDailyEnabled || isWeeklyEnabled else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Schedule for the next 7 days
        for i in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            
            // Set time to 5:00 AM
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 5
            components.minute = 0
            
            guard let fireDate = calendar.date(from: components) else { continue }
            let isMonday = components.weekday == 2 // 1 = Sunday, 2 = Monday
            
            // Check conflicts
            if isMonday && isWeeklyEnabled {
                // Schedule WEEKLY digest
                let dueThisWeek = tasks.filter { task in
                    guard !task.isCompleted, let due = task.dueDate else { return false }
                    // Check if due between fireDate and fireDate + 7 days
                    guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: fireDate) else { return false }
                    return due >= fireDate && due < weekEnd
                }
                
                if !dueThisWeek.isEmpty {
                    scheduleDigest(
                        identifier: "digest_weekly_\(i)",
                        title: "Weekly Task Summary",
                        body: "You have \(dueThisWeek.count) tasks due this upcoming week.",
                        dateComponents: components
                    )
                }
                
                // Do NOT schedule Daily digest if Weekly is scheduled and conflict rule is active
                // Requirement: "if they select both 3 and 4... only show a notification of tasks due in the coming week on Mondays"
                
            } else if isDailyEnabled {
                // Schedule DAILY digest
                let dueToday = tasks.filter { task in
                    guard !task.isCompleted, let due = task.dueDate else { return false }
                    // Check if due on this specific day (fireDate to fireDate + 24h)
                    // Note: fireDate is 5am. The prompt says "tasks due the coming day". 
                    // Usually "due today" means 00:00 to 23:59 of that day. 
                    // Let's assume the digest at 5am is for tasks due *that same day* (from 00:00 to 23:59).
                    // Or implies tasks due *after* 5am? "coming day" is ambiguous. "Due today" is safest interpretation.
                    return calendar.isDate(due, inSameDayAs: fireDate)
                }
                
                if !dueToday.isEmpty {
                    scheduleDigest(
                        identifier: "digest_daily_\(i)",
                        title: "Daily Task Summary",
                        body: "You have \(dueToday.count) tasks due today.",
                        dateComponents: components
                    )
                }
            }
        }
    }
    
    private func scheduleDigest(identifier: String, title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling digest \(identifier): \(error)")
            }
        }
    }
    
    func refreshDigests(tasks: [TaskItem]) {
        let defaults = UserDefaults.standard
        let master = defaults.bool(forKey: "notificationsEnabled")
        let daily = defaults.bool(forKey: "dailyDigestEnabled")
        let weekly = defaults.bool(forKey: "weeklyDigestEnabled")
        
        let shouldScheduleDaily = master && daily
        let shouldScheduleWeekly = master && weekly
        
        rescheduleDigests(tasks: tasks, isDailyEnabled: shouldScheduleDaily, isWeeklyEnabled: shouldScheduleWeekly)
    }
}
