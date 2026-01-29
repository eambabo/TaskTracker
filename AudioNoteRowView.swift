//
//  AudioNoteRowView.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import SwiftUI

struct AudioNoteRowView: View {
    let audioNote: AudioNote

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(audioNote.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(audioNote.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if audioNote.isTranscribed {
                        Label("Transcribed", systemImage: "text.bubble")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Text(audioNote.createdAt, format: .dateTime.month().day())
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
