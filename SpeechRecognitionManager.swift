//
//  SpeechRecognitionManager.swift
//  TaskTracker
//
//  Created by Claude on 1/29/26.
//

import Foundation
import Speech

@Observable
final class SpeechRecognitionManager {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    enum SpeechError: LocalizedError {
        case notAuthorized
        case notAvailable
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition is not authorized. Please enable it in Settings."
            case .notAvailable:
                return "Speech recognition is not available on this device."
            case .recognitionFailed(let message):
                return "Recognition failed: \(message)"
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        requestAuthorization { [weak self] authorized in
            guard authorized else {
                completion(.failure(SpeechError.notAuthorized))
                return
            }

            self?.performTranscription(audioURL: audioURL, completion: completion)
        }
    }

    private func performTranscription(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            completion(.failure(SpeechError.notAvailable))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(SpeechError.recognitionFailed(error.localizedDescription)))
                }
                return
            }

            guard let result = result else {
                DispatchQueue.main.async {
                    completion(.failure(SpeechError.recognitionFailed("No result returned")))
                }
                return
            }

            if result.isFinal {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    completion(.success(transcription))
                }
            }
        }
    }
}
