//
//  OpenAIRealtimeInterpreterService.swift
//  Nekko
//
//  Created by GPT-5.5 on 2026/05/27.
//

import AVFoundation
import Foundation

@Observable
final class OpenAIRealtimeInterpreterService: @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var isSpeaking = false
    private(set) var sourceTranscript = ""
    private(set) var translatedTranscript = ""
    private(set) var error: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var pendingAudioData = Data()
    private let sendLock = NSLock()
    private var isStopping = false
    private let audioPlayer = PCM16AudioPlayer(sampleRate: 24_000)
    private var currentModel = ""

    private static let inputSampleRate: Double = 24_000
    private static let outputSampleRate: Double = 24_000
    private static let wsBaseURL = "wss://api.openai.com/v1/realtime"
    private static let modelCandidates = [
        "gpt-realtime",
        "gpt-4o-realtime-preview",
    ]

    var apiKey: String {
        (UserDefaults.standard.string(forKey: "nekko_openai_api_key") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Public

    func start(direction: InterpreterDirection) async {
        guard hasAPIKey else {
            await setError("OpenAI APIキーが設定されていません。設定画面から入力してください。")
            return
        }

        isStopping = false
        pendingAudioData = Data()

        await MainActor.run {
            sourceTranscript = ""
            translatedTranscript = ""
            error = nil
            isSpeaking = false
        }

        do {
            try audioPlayer.start()

            var lastErrorMessage = "接続に失敗しました。"
            var attemptedModels: [String] = []

            for model in Self.modelCandidates {
                attemptedModels.append(model)
                do {
                    try await connectWebSocket(direction: direction, model: model)
                    return
                } catch {
                    lastErrorMessage = error.localizedDescription
                    await resetConnectionStateForRetry()
                    if shouldStopRetrying(for: lastErrorMessage) {
                        break
                    }
                }
            }

            let attempted = attemptedModels.joined(separator: ", ")
            await setError(
                """
                OpenAI Realtime接続に失敗しました。
                \(lastErrorMessage)
                試行モデル: \(attempted)
                """
            )
        } catch {
            await setError("OpenAI Realtime接続に失敗しました: \(error.localizedDescription)")
        }
    }

    func updateDirection(_ direction: InterpreterDirection) async {
        guard isConnected else { return }
        await sendSessionUpdate(direction: direction)
    }

    func stop() async {
        guard !isStopping else { return }
        isStopping = true

        if isConnected {
            sendPendingAudio()
            sendJSON(["type": "input_audio_buffer.commit"])
            sendJSON(["type": "response.create"])
        }

        try? await Task.sleep(for: .milliseconds(300))

        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        audioConverter = nil
        audioPlayer.stop()

        await MainActor.run {
            isConnected = false
            isSpeaking = false
        }
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isConnected, !isStopping else { return }

        let pcmData = convertToTargetFormat(buffer: buffer)
        guard !pcmData.isEmpty else { return }

        sendLock.lock()
        pendingAudioData.append(pcmData)

        let chunkSize = Int(Self.inputSampleRate) * 2 * 100 / 1000
        while pendingAudioData.count >= chunkSize {
            let chunk = pendingAudioData.prefix(chunkSize)
            pendingAudioData = Data(pendingAudioData.dropFirst(chunkSize))
            sendLock.unlock()
            sendAudioChunk(Data(chunk))
            sendLock.lock()
        }
        sendLock.unlock()
    }

    // MARK: - WebSocket

    private func connectWebSocket(direction: InterpreterDirection, model: String) async throws {
        currentModel = model

        var components = URLComponents(string: Self.wsBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "model", value: model),
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        let session = URLSession(configuration: config)
        urlSession = session
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        try await waitForSessionCreated()
        await sendSessionUpdate(direction: direction)
    }

    private func waitForSessionCreated() async throws {
        let deadline = ContinuousClock.now + .seconds(10)

        while ContinuousClock.now < deadline {
            if isConnected { return }
            if let error {
                throw NSError(domain: "OpenAIRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            if let task = webSocketTask, task.closeCode != .invalid {
                let closeMessage = formattedCloseMessage(for: task)
                throw NSError(domain: "OpenAIRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: closeMessage])
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        throw NSError(domain: "OpenAIRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: "セッション作成がタイムアウトしました"])
    }

    private func sendSessionUpdate(direction: InterpreterDirection) async {
        let session: [String: Any] = [
            "type": "realtime",
            "instructions": direction.instructions,
            "output_modalities": ["audio"],
            "audio": [
                "input": [
                    "format": [
                        "type": "audio/pcm",
                        "rate": Int(Self.inputSampleRate),
                    ],
                    "transcription": [
                        "model": "whisper-1",
                    ],
                    "turn_detection": [
                        "type": "server_vad",
                        "threshold": NSNumber(value: 0.5),
                        "prefix_padding_ms": 300,
                        "silence_duration_ms": 700,
                    ],
                ],
                "output": [
                    "format": [
                        "type": "audio/pcm",
                        "rate": Int(Self.outputSampleRate),
                    ],
                    "voice": "alloy",
                ],
            ],
        ]

        sendJSON([
            "type": "session.update",
            "session": session,
        ])
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handleServerEvent(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleServerEvent(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !isStopping {
                    let closeMessage = formattedCloseMessage(for: task)
                    let message = "WebSocket受信エラー: \(error.localizedDescription)\n\(closeMessage)"
                    await setError(message)
                }
                break
            }
        }
    }

    private func handleServerEvent(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else {
            print("[OpenAIRealtime] Failed to parse event: \(text.prefix(200))")
            return
        }

        Task { @MainActor in
            switch type {
            case "session.created":
                self.isConnected = true

            case "session.updated":
                break

            case "input_audio_buffer.speech_started":
                self.isSpeaking = false
                self.audioPlayer.reset()

            case "input_audio_buffer.speech_stopped":
                self.isSpeaking = false

            case "conversation.item.input_audio_transcription.completed":
                if let transcript = json["transcript"] as? String {
                    self.sourceTranscript = transcript
                }

            case "response.audio.delta", "response.output_audio.delta":
                if let delta = json["delta"] as? String,
                   let audioData = Data(base64Encoded: delta) {
                    self.isSpeaking = true
                    self.audioPlayer.enqueue(audioData)
                }

            case "response.audio_transcript.delta",
                 "response.output_audio_transcript.delta",
                 "response.output_text.delta":
                if let delta = json["delta"] as? String {
                    self.translatedTranscript += delta
                }

            case "response.audio.done", "response.output_audio.done", "response.done":
                self.isSpeaking = false

            case "error":
                let message: String
                if let errorObject = json["error"] as? [String: Any],
                   let errorMessage = errorObject["message"] as? String {
                    message = errorMessage
                } else {
                    message = "OpenAI Realtime APIエラーが発生しました"
                }
                self.error = message
                self.isConnected = false

            default:
                print("[OpenAIRealtime] Event: \(type)")
            }
        }
    }

    // MARK: - Audio Send

    private func sendAudioChunk(_ data: Data) {
        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString(),
        ])
    }

    private func sendPendingAudio() {
        sendLock.lock()
        if !pendingAudioData.isEmpty {
            let remaining = pendingAudioData
            pendingAudioData = Data()
            sendLock.unlock()
            sendAudioChunk(remaining)
        } else {
            sendLock.unlock()
        }
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8)
        else { return }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error {
                print("[OpenAIRealtime] Send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Conversion (to 24kHz mono S16LE)

    private func convertToTargetFormat(buffer: AVAudioPCMBuffer) -> Data {
        let inputFormat = buffer.format
        let targetRate = Self.inputSampleRate

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetRate,
            channels: 1,
            interleaved: true
        ) else { return Data() }

        if inputFormat.sampleRate == targetRate && inputFormat.channelCount == 1 && inputFormat.commonFormat == .pcmFormatInt16 {
            return bufferToData(buffer)
        }

        if audioConverter == nil || audioConverter?.inputFormat != inputFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }

        guard let converter = audioConverter else { return Data() }

        let ratio = targetRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount)
        else { return Data() }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return Data() }
        return bufferToData(outputBuffer)
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return Data() }

        if buffer.format.commonFormat == .pcmFormatInt16, let int16Data = buffer.int16ChannelData {
            return Data(bytes: int16Data[0], count: frameCount * 2)
        }

        if let floatData = buffer.floatChannelData {
            var data = Data(count: frameCount * 2)
            data.withUnsafeMutableBytes { rawBuffer in
                let int16Ptr = rawBuffer.bindMemory(to: Int16.self)
                for index in 0..<frameCount {
                    let sample = max(-1.0, min(1.0, floatData[0][index]))
                    int16Ptr[index] = Int16(sample * Float(Int16.max))
                }
            }
            return data
        }

        return Data()
    }

    private func setError(_ message: String) async {
        await MainActor.run {
            error = message
            isConnected = false
            isSpeaking = false
        }
    }

    private func resetConnectionStateForRetry() async {
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        receiveTask = nil
        webSocketTask = nil
        urlSession = nil

        await MainActor.run {
            isConnected = false
            isSpeaking = false
        }
    }

    private func shouldStopRetrying(for message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("invalid_api_key")
            || lower.contains("authentication")
            || lower.contains("unauthorized")
            || lower.contains("incorrect api key")
            || lower.contains("permission")
    }

    private func formattedCloseMessage(for task: URLSessionWebSocketTask) -> String {
        var details = "WebSocketが切断されました（モデル: \(currentModel)）"
        if task.closeCode != .invalid {
            details += " / closeCode: \(task.closeCode.rawValue)"
        }
        if let reason = task.closeReason,
           let reasonText = String(data: reason, encoding: .utf8),
           !reasonText.isEmpty {
            details += " / reason: \(reasonText)"
        }
        return details
    }
}

private final class PCM16AudioPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let lock = NSLock()
    private var isStarted = false

    init(sampleRate: Double) {
        format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }

        if !engine.isRunning {
            try engine.start()
        }
        if !player.isPlaying {
            player.play()
        }
        isStarted = true
    }

    func enqueue(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard isStarted, let buffer = makeBuffer(from: data) else { return }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        player.stop()
        player.play()
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        player.stop()
        engine.stop()
        isStarted = false
    }

    private func makeBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for index in 0..<sampleCount {
                channel[index] = Float(samples[index]) / Float(Int16.max)
            }
        }

        return buffer
    }
}
