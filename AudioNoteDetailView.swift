//
//  AudioNoteDetailView.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import SwiftData

struct AudioNoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var audioNote: AudioNote

    @State private var player = AudioPlayerManager()
    @State private var speechManager = SpeechRecognitionManager()
    @State private var isTranscribing = false
    @State private var showTaskReview = false
    @State private var extractedTasks: [ExtractedTask] = []
    @State private var isExtracting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                playerSection

                if let transcription = audioNote.transcription, !transcription.isEmpty {
                    transcriptionSection(transcription)
                    extractionSection
                } else {
                    transcribeButton
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(audioNote.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            player.stop()
        }
        .sheet(isPresented: $showTaskReview) {
            TaskReviewView(extractedTasks: $extractedTasks)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(player.formattedTime(player.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Slider(value: Binding(
                    get: { player.progress },
                    set: { player.seek(to: $0 * player.duration) }
                ), in: 0...1)

                Text(player.formattedTime(player.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }

            HStack(spacing: 40) {
                Button {
                    player.seek(to: max(0, player.currentTime - 15))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                }

                Button {
                    player.seek(to: min(player.duration, player.currentTime + 15))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func transcriptionSection(_ transcription: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcription", systemImage: "text.bubble")
                .font(.headline)

            Text(transcription)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var transcribeButton: some View {
        Button {
            transcribe()
        } label: {
            HStack {
                if isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "text.bubble")
                }
                Text(isTranscribing ? "Transcribing..." : "Transcribe")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isTranscribing)
    }

    private var extractionSection: some View {
        Button {
            extractTasks()
        } label: {
            HStack {
                if isExtracting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                } else {
                    Image(systemName: "checklist")
                }
                Text(isExtracting ? "Extracting Tasks..." : "Extract Tasks")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isExtracting || audioNote.transcription == nil)
    }

    private func loadAudio() {
        guard let url = audioNote.audioURL else { return }
        _ = player.loadAudio(from: url)
    }

    private func transcribe() {
        guard let url = audioNote.audioURL else {
            errorMessage = "Audio file not found"
            return
        }

        isTranscribing = true
        errorMessage = nil

        speechManager.transcribe(audioURL: url) { result in
            DispatchQueue.main.async {
                isTranscribing = false

                switch result {
                case .success(let transcription):
                    audioNote.transcription = transcription
                    audioNote.isTranscribed = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func extractTasks() {
        guard let transcription = audioNote.transcription else { return }

        isExtracting = true
        errorMessage = nil

        Task {
            let extractor = TaskExtractionManager()
            let tasks = await extractor.extractTasks(from: transcription)

            await MainActor.run {
                isExtracting = false
                extractedTasks = tasks
                if !tasks.isEmpty {
                    showTaskReview = true
                } else {
                    errorMessage = "No tasks found in the transcription"
                }
            }
        }
    }
}
