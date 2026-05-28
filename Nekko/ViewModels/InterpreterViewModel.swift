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
    var isSessionActive = false
    var isHolding = false
    var permissionsGranted = false
    var errorMessage: String?
    var showError = false

    private var audioRecorder = AudioRecorderService()
    private let realtimeService = OpenAIRealtimeInterpreterService()
    private var isStarting = false

    var hasAPIKey: Bool {
        realtimeService.hasAPIKey
    }

    var isConnected: Bool {
        realtimeService.isConnected
    }

    var isSpeaking: Bool {
        realtimeService.isSpeaking
    }

    var hasError: Bool {
        realtimeService.error != nil
    }

    /// 接続中・エラー時のみ表示（通常は nil）
    var statusLine: String? {
        if let serviceError = realtimeService.error {
            return serviceError
        }
        if isSpeaking {
            return "通訳してるニャ..."
        }
        if isHolding {
            return "聞いてるニャ..."
        }
        if isSessionActive, !isConnected {
            return "つないでるニャ..."
        }
        if !hasAPIKey {
            return "設定でOpenAI APIキーを入れてニャ"
        }
        return nil
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

    func start() async {
        guard !isStarting, !isSessionActive else { return }
        guard permissionsGranted else { return }

        guard realtimeService.hasAPIKey else {
            await MainActor.run {
                errorMessage = "OpenAI APIキーが設定されていません。設定タブから入力してください。"
                showError = true
            }
            return
        }

        isStarting = true
        defer { isStarting = false }

        await MainActor.run {
            isSessionActive = true
        }

        await realtimeService.start(direction: .automatic)

        if let realtimeError = realtimeService.error {
            await MainActor.run {
                isSessionActive = false
                errorMessage = realtimeError
                showError = true
            }
            return
        }

        await MainActor.run {
            do {
                audioRecorder.onAudioBuffer = { [weak self] buffer in
                    self?.realtimeService.processAudioBuffer(buffer)
                }

                audioRecorder.isCapturing = false
                _ = try audioRecorder.startRecording(
                    fileName: "nekko_interpreter_\(Int(Date().timeIntervalSince1970))",
                    allowsPlayback: true
                )
            } catch {
                isSessionActive = false
                errorMessage = "マイクを開始できませんでした: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func stop() {
        isHolding = false
        audioRecorder.isCapturing = false
        _ = audioRecorder.stopRecording()
        isSessionActive = false

        Task {
            await realtimeService.stop()
        }
    }

    func beginHold() {
        guard isSessionActive, !isHolding else { return }

        isHolding = true
        audioRecorder.isCapturing = true

        guard isConnected else { return }

        Task {
            await realtimeService.prepareForNewTurn()
        }
    }

    func endHold() {
        guard isHolding else { return }

        isHolding = false
        audioRecorder.isCapturing = false

        guard isSessionActive else { return }

        Task {
            await realtimeService.commitTurn()
        }
    }
}
