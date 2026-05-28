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
    var isSessionActive = false
    var isHolding = false
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

    var statusMessage: String {
        if let serviceError = realtimeService.error {
            return serviceError
        }
        if isSpeaking {
            return selectedDirection.speakingMessage
        }
        if isHolding {
            return selectedDirection.holdingMessage
        }
        if isSessionActive, isConnected {
            return "ボタンを押して話すニャ"
        }
        if isSessionActive {
            return "OpenAIにつないでるニャ..."
        }
        if hasAPIKey {
            return "通訳を始めてから、押して話すニャ"
        }
        return "設定でOpenAI APIキーを入れてニャ"
    }

    var helperMessage: String {
        switch selectedDirection {
        case .japaneseToEnglish:
            "押している間だけ日本語を聞き、離すと英語で通訳します。"
        case .englishToJapanese:
            "押している間だけ英語を聞き、離すと日本語で通訳します。"
        case .automatic:
            "押している間だけ聞き、離すと反対の言語に通訳します。"
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

    func toggleSession() {
        if isSessionActive {
            endSession()
        } else {
            startSession()
        }
    }

    func updateDirection(_ direction: InterpreterDirection) {
        selectedDirection = direction
        guard isSessionActive else { return }

        Task {
            await realtimeService.updateDirection(direction)
        }
    }

    func beginHold() {
        guard isSessionActive, isConnected, !isHolding else { return }

        isHolding = true
        audioRecorder.isCapturing = true
        audioLevels = Array(repeating: 0, count: 48)

        Task {
            await realtimeService.prepareForNewTurn()
        }
    }

    func endHold() {
        guard isHolding else { return }

        isHolding = false
        audioRecorder.isCapturing = false
        audioLevels = Array(repeating: 0, count: 48)

        Task {
            await realtimeService.commitTurn()
        }
    }

    private func startSession() {
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

                    self.audioRecorder.isCapturing = false
                    _ = try self.audioRecorder.startRecording(
                        fileName: "nekko_interpreter_\(Int(Date().timeIntervalSince1970))",
                        allowsPlayback: true
                    )
                    self.isSessionActive = true
                } catch {
                    self.errorMessage = "マイクを開始できませんでした: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    private func endSession() {
        if isHolding {
            endHold()
        }

        audioRecorder.isCapturing = false
        _ = audioRecorder.stopRecording()
        isSessionActive = false
        audioLevels = Array(repeating: 0, count: 48)

        Task {
            await realtimeService.stop()
        }
    }
}
