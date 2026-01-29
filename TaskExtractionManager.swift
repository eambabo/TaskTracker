//
//  TaskExtractionManager.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct ExtractedTask: Identifiable {
    let id = UUID()
    var title: String
    var priority: TaskPriority
    var dueDateDescription: String?
    var isSelected: Bool = true
}

final class TaskExtractionManager {

    func extractTasks(from text: String) async -> [ExtractedTask] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let tasks = await extractWithFoundationModels(text: text) {
                return tasks
            }
        }
        #endif

        return extractWithFallback(text: text)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractWithFoundationModels(text: String) async -> [ExtractedTask]? {
        do {
            let session = LanguageModelSession()

            let prompt = """
            Extract actionable tasks from the following voice memo transcription.
            For each task, provide:
            - A clear, concise title
            - Priority level (low, medium, or high)
            - Due date description if mentioned (e.g., "tomorrow", "next week", "Friday")

            Transcription:
            \(text)

            Return the tasks as a JSON array with objects containing "title", "priority", and "dueDateDescription" fields.
            Only include actual actionable tasks, not observations or notes.
            """

            let response = try await session.respond(to: prompt)
            return parseFoundationModelsResponse(response.content)
        } catch {
            print("Foundation Models extraction failed: \(error)")
            return nil
        }
    }

    private func parseFoundationModelsResponse(_ content: String) -> [ExtractedTask]? {
        guard let jsonStart = content.firstIndex(of: "["),
              let jsonEnd = content.lastIndex(of: "]") else {
            return nil
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            let decoded = try JSONDecoder().decode([FoundationModelTask].self, from: data)
            return decoded.map { task in
                ExtractedTask(
                    title: task.title,
                    priority: parsePriority(task.priority),
                    dueDateDescription: task.dueDateDescription
                )
            }
        } catch {
            print("Failed to parse Foundation Models response: \(error)")
            return nil
        }
    }

    private struct FoundationModelTask: Decodable {
        let title: String
        let priority: String
        let dueDateDescription: String?
    }
    #endif

    private func extractWithFallback(text: String) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let actionPatterns = [
            "need to",
            "have to",
            "must",
            "should",
            "going to",
            "gonna",
            "want to",
            "wanna",
            "don't forget",
            "remember to",
            "remind me to",
            "make sure to",
            "got to",
            "gotta"
        ]

        let actionVerbs = [
            "call", "email", "text", "message", "contact",
            "buy", "get", "pick up", "purchase",
            "finish", "complete", "do",
            "schedule", "book", "arrange",
            "send", "submit", "deliver",
            "fix", "repair", "update",
            "clean", "organize", "prepare",
            "review", "check", "verify",
            "meet", "visit", "attend",
            "pay", "transfer", "deposit",
            "write", "draft", "create"
        ]

        let highPriorityKeywords = ["urgent", "asap", "immediately", "critical", "important", "today", "now", "right away"]
        let lowPriorityKeywords = ["eventually", "sometime", "when possible", "no rush", "later", "someday"]

        for sentence in sentences {
            let lowercased = sentence.lowercased()

            var isTask = false
            var taskTitle = sentence

            for pattern in actionPatterns {
                if lowercased.contains(pattern) {
                    isTask = true
                    if let range = lowercased.range(of: pattern) {
                        let afterPattern = String(sentence[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !afterPattern.isEmpty {
                            taskTitle = afterPattern.prefix(1).uppercased() + afterPattern.dropFirst()
                        }
                    }
                    break
                }
            }

            if !isTask {
                for verb in actionVerbs {
                    if lowercased.hasPrefix(verb) || lowercased.contains(" \(verb) ") {
                        isTask = true
                        break
                    }
                }
            }

            if isTask {
                var priority = TaskPriority.medium

                for keyword in highPriorityKeywords {
                    if lowercased.contains(keyword) {
                        priority = .high
                        break
                    }
                }

                if priority == .medium {
                    for keyword in lowPriorityKeywords {
                        if lowercased.contains(keyword) {
                            priority = .low
                            break
                        }
                    }
                }

                let dueDateDescription = extractDueDate(from: lowercased)

                let cleanTitle = taskTitle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "^(to |the |a |an )", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleanTitle.isEmpty && cleanTitle.count > 3 {
                    let finalTitle = cleanTitle.prefix(1).uppercased() + cleanTitle.dropFirst()
                    tasks.append(ExtractedTask(
                        title: String(finalTitle),
                        priority: priority,
                        dueDateDescription: dueDateDescription
                    ))
                }
            }
        }

        return tasks
    }

    private func extractDueDate(from text: String) -> String? {
        let datePatterns = [
            "today", "tonight",
            "tomorrow", "tomorrow morning", "tomorrow afternoon", "tomorrow evening",
            "next week", "next month",
            "this week", "this weekend",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "by end of day", "by eod", "end of week", "end of month"
        ]

        for pattern in datePatterns {
            if text.contains(pattern) {
                return pattern.capitalized
            }
        }

        return nil
    }

    private func parsePriority(_ string: String) -> TaskPriority {
        switch string.lowercased() {
        case "high": return .high
        case "low": return .low
        default: return .medium
        }
    }
}
