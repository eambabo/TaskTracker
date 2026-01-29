//
//  AudioNotesTab.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import SwiftData

struct AudioNotesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioNote.createdAt, order: .reverse) private var audioNotes: [AudioNote]
    @State private var showRecordingView = false
    @State private var recorder = AudioRecorderManager()

    var body: some View {
        NavigationStack {
            Group {
                if audioNotes.isEmpty {
                    ContentUnavailableView(
                        "No Audio Notes",
                        systemImage: "waveform",
                        description: Text("Tap the microphone button to record a voice memo.")
                    )
                } else {
                    List {
                        ForEach(audioNotes) { note in
                            NavigationLink(destination: AudioNoteDetailView(audioNote: note)) {
                                AudioNoteRowView(audioNote: note)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Audio Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showRecordingView = true
                    } label: {
                        Label("Record", systemImage: "mic.fill")
                    }
                }
            }
            .sheet(isPresented: $showRecordingView) {
                RecordingView()
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let note = audioNotes[index]
                recorder.deleteRecording(fileName: note.audioFileName)
                modelContext.delete(note)
            }
        }
    }
}
