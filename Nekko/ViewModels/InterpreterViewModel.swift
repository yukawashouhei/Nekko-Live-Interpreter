//
//  InterpreterViewModel.swift
//  Nekko
//
//  Created by GPT-5.5 on 2026/05/27.
//

import AVFoundation
import Foundation

@Observable
final class InterpreterViewModel {
    var selectedDirection: InterpreterDirection = .japaneseToEnglish
    var isInterpreting = false
    var permissionsGranted = false
    var audioLevels: [Float] = Array(repeating: 0, count: 48)
    var errorMessage: String?
    var showError = false

    private var audioRecorder = AudioRecorderService()
    private let realtimeService = OpenAIRealtimeInterpreterService()

    var hasAPIKey: Bool {
        realtimeService.hasAPIKey
    }

    var isConnected: Bool {
        realtimeService.isConnected
    }

    var isSpeaking: Bool {
        realtimeService.isSpeaking
    }

    var sourceTranscript: String {
        realtimeService.sourceTranscript
    }

    var translatedTranscript: String {
        realtimeService.translatedTranscript
    }

    var serviceError: String? {
        realtimeService.error
    }

    var statusMessage: String {
        if let serviceError {
            return serviceError
        }
        if isSpeaking {
            return selectedDirection.speakingMessage
        }
        if isInterpreting, isConnected {
            return selectedDirection.listeningMessage
        }
        if isInterpreting {
            return "OpenAIにつないでるニャ..."
        }
        if hasAPIKey {
            return "話しかけてほしいニャ"
        }
        return "設定でOpenAI APIキーを入れてニャ"
    }

    var helperMessage: String {
        switch selectedDirection {
        case .japaneseToEnglish:
            "日本語で話すと、Nekkoが英語で可愛く通訳します。"
        case .englishToJapanese:
            "英語の質問を聞かせると、Nekkoが日本語に戻します。"
        case .automatic:
            "日本語と英語を聞き分けて、反対の言語に通訳します。"
        }
    }

    func checkPermissions() async {
        let micGranted = await AVAudioApplication.requestRecordPermission()

        await MainActor.run {
            permissionsGranted = micGranted
            if !permissionsGranted {
                errorMessage = "マイクの権限が必要です。設定アプリから許可してください。"
                showError = true
            }
        }
    }

    func toggleInterpreter() {
        if isInterpreting {
            stopInterpreter()
        } else {
            startInterpreter()
        }
    }

    func updateDirection(_ direction: InterpreterDirection) {
        selectedDirection = direction
        guard isInterpreting else { return }

        Task {
            await realtimeService.updateDirection(direction)
        }
    }

    private func startInterpreter() {
        guard permissionsGranted else {
            errorMessage = "マイクの権限が必要です。"
            showError = true
            return
        }

        guard realtimeService.hasAPIKey else {
            errorMessage = "OpenAI APIキーが設定されていません。設定タブから入力してください。"
            showError = true
            return
        }

        audioLevels = Array(repeating: 0, count: 48)

        Task {
            await realtimeService.start(direction: selectedDirection)

            if let realtimeError = realtimeService.error {
                await MainActor.run {
                    errorMessage = realtimeError
                    showError = true
                }
                return
            }

            await MainActor.run {
                do {
                    self.audioRecorder.onAudioLevelUpdate = { [weak self] level in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.audioLevels.append(level)
                            if self.audioLevels.count > 48 {
                                self.audioLevels.removeFirst()
                            }
                        }
                    }

                    self.audioRecorder.onAudioBuffer = { [weak self] buffer in
                        self?.realtimeService.processAudioBuffer(buffer)
                    }

                    _ = try self.audioRecorder.startRecording(
                        fileName: "nekko_interpreter_\(Int(Date().timeIntervalSince1970))",
                        allowsPlayback: true
                    )
                    self.isInterpreting = true
                } catch {
                    self.errorMessage = "マイクを開始できませんでした: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    private func stopInterpreter() {
        _ = audioRecorder.stopRecording()
        isInterpreting = false
        audioLevels = Array(repeating: 0, count: 48)

        Task {
            await realtimeService.stop()
        }
    }
}
