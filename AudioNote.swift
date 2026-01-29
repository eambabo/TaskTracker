//
//  AudioNote.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import SwiftData

@Model
final class AudioNote {
    var id: UUID
    var title: String
    var audioFileName: String
    var transcription: String?
    var duration: TimeInterval
    var createdAt: Date
    var isTranscribed: Bool

    init(title: String, audioFileName: String, duration: TimeInterval) {
        self.id = UUID()
        self.title = title
        self.audioFileName = audioFileName
        self.transcription = nil
        self.duration = duration
        self.createdAt = Date()
        self.isTranscribed = false
    }

    var audioURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("AudioNotes").appendingPathComponent(audioFileName)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
