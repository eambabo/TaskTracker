//
//  AudioRecorderManager.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import AVFoundation
import Foundation

@Observable
final class AudioRecorderManager: NSObject {
    var isRecording = false
    var recordingTime: TimeInterval = 0
    var audioLevels: [Float] = []

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var currentFileName: String?

    private let audioNotesDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioNotesPath = documentsPath.appendingPathComponent("AudioNotes")

        if !FileManager.default.fileExists(atPath: audioNotesPath.path) {
            try? FileManager.default.createDirectory(at: audioNotesPath, withIntermediateDirectories: true)
        }

        return audioNotesPath
    }()

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startRecording() -> String? {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return nil
        }

        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = audioNotesDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            recordingTime = 0
            audioLevels = []
            currentFileName = fileName

            startTimers()

            return fileName
        } catch {
            print("Failed to start recording: \(error)")
            return nil
        }
    }

    func stopRecording() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        let duration = recorder.currentTime
        let fileName = currentFileName

        recorder.stop()
        stopTimers()

        isRecording = false
        audioRecorder = nil
        currentFileName = nil

        if let fileName = fileName {
            return (fileName, duration)
        }
        return nil
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }

        recorder.stop()
        stopTimers()

        if let fileName = currentFileName {
            let fileURL = audioNotesDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }

        isRecording = false
        audioRecorder = nil
        currentFileName = nil
        recordingTime = 0
        audioLevels = []
    }

    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingTime += 1
        }

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()

        let level = recorder.averagePower(forChannel: 0)
        let normalizedLevel = max(0, (level + 60) / 60)

        audioLevels.append(normalizedLevel)
        if audioLevels.count > 50 {
            audioLevels.removeFirst()
        }
    }

    func deleteRecording(fileName: String) {
        let fileURL = audioNotesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension AudioRecorderManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
    }
}
