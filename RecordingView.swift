//
//  RecordingView.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var recorder = AudioRecorderManager()
    @State private var showPermissionAlert = false
    @State private var currentFileName: String?
    @State private var noteTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                Text(formattedTime)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(recorder.isRecording ? .red : .primary)

                WaveformView(levels: recorder.audioLevels)
                    .frame(height: 80)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 60) {
                    if recorder.isRecording {
                        Button {
                            cancelRecording()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                        }

                        Button {
                            stopRecording()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            startRecording()
                        } label: {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Record Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if recorder.isRecording {
                            cancelRecording()
                        }
                        dismiss()
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow microphone access in Settings to record voice memos.")
            }
        }
    }

    private var formattedTime: String {
        let minutes = Int(recorder.recordingTime) / 60
        let seconds = Int(recorder.recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startRecording() {
        recorder.requestPermission { granted in
            if granted {
                currentFileName = recorder.startRecording()
            } else {
                showPermissionAlert = true
            }
        }
    }

    private func stopRecording() {
        guard let result = recorder.stopRecording() else { return }

        let title = "Voice Memo \(formattedDate)"
        let audioNote = AudioNote(
            title: title,
            audioFileName: result.fileName,
            duration: result.duration
        )
        modelContext.insert(audioNote)

        dismiss()
    }

    private func cancelRecording() {
        recorder.cancelRecording()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { index in
                    let level = index < levels.count ? CGFloat(levels[index]) : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.opacity(0.7))
                        .frame(width: (geometry.size.width - 98) / 50, height: max(4, level * geometry.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
