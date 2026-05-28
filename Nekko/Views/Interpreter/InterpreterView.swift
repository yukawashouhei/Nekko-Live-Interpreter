//
//  InterpreterView.swift
//  Nekko
//
//  Created by GPT-5.5 on 2026/05/27.
//

import SwiftUI

struct InterpreterView: View {
    @State private var viewModel = InterpreterViewModel()
    @State private var currentCatIndex: Int = 1
    @State private var pulseCat = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.18),
                        Color(.systemGroupedBackground),
                        Color.blue.opacity(0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        directionPicker
                        waveformSection
                        transcriptSection
                        sessionButton
                        holdButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Nekko Interpreter")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.checkPermissions()
            }
            .onAppear {
                currentCatIndex = Int.random(in: 1...6)
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseCat = true
                }
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.18))
                    .frame(width: 196, height: 196)
                    .scaleEffect(isCatPulsing ? (pulseCat ? 1.08 : 0.96) : 1)

                Circle()
                    .stroke(.orange.opacity(0.25), lineWidth: 2)
                    .frame(width: 212, height: 212)

                Image("Cat\(currentCatIndex)")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 156)
                    .shadow(color: .orange.opacity(0.25), radius: 18, y: 8)
                    .accessibilityLabel("Nekko")
            }

            VStack(spacing: 8) {
                Text(viewModel.statusMessage)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(viewModel.helperMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if viewModel.isSessionActive {
                Label(
                    viewModel.isConnected ? "Live with OpenAI Realtime" : "Connecting...",
                    systemImage: viewModel.isConnected ? "dot.radiowaves.left.and.right" : "hourglass"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(viewModel.isConnected ? .green : .orange)
            }
        }
        .padding(.top, 12)
    }

    private var isCatPulsing: Bool {
        viewModel.isHolding || viewModel.isSpeaking
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通訳方向")
                .font(.headline)

            Picker("通訳方向", selection: $viewModel.selectedDirection) {
                ForEach(InterpreterDirection.allCases) { direction in
                    Text(direction.shortTitle)
                        .tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isHolding)
            .onChange(of: viewModel.selectedDirection) { _, newValue in
                viewModel.updateDirection(newValue)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                Text(waveformLabel)
                Spacer()
                Text(viewModel.selectedDirection.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))

            AudioWaveformView(levels: viewModel.audioLevels)
                .frame(height: 72)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var waveformLabel: String {
        if viewModel.isHolding {
            "Recording, meow..."
        } else if viewModel.isSessionActive {
            "Hold to speak"
        } else {
            "Ready"
        }
    }

    private var transcriptSection: some View {
        VStack(spacing: 12) {
            transcriptCard(
                title: "聞き取った内容",
                icon: "ear.fill",
                text: viewModel.sourceTranscript,
                placeholder: "ここに原文が出るニャ"
            )

            transcriptCard(
                title: "Nekkoの通訳",
                icon: "bubble.left.and.bubble.right.fill",
                text: viewModel.translatedTranscript,
                placeholder: "ここに通訳が出るニャ / Translation appears here, meow."
            )
        }
    }

    private func transcriptCard(title: String, icon: String, text: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(text.isEmpty ? placeholder : text)
                .font(.body)
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                .textSelection(.enabled)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var sessionButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.toggleSession()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isSessionActive ? "xmark.circle.fill" : "power")
                Text(viewModel.isSessionActive ? "セッションを終了" : "通訳を始めるニャ")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(viewModel.isSessionActive ? .red : .orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .disabled(!viewModel.permissionsGranted)
        .opacity(viewModel.permissionsGranted ? 1 : 0.55)
        .sensoryFeedback(.impact, trigger: viewModel.isSessionActive)
    }

    private var holdButton: some View {
        let isEnabled = viewModel.isSessionActive && viewModel.isConnected

        return ZStack {
            Circle()
                .fill(holdButtonColor.gradient)
                .frame(width: holdButtonSize, height: holdButtonSize)
                .shadow(color: .orange.opacity(viewModel.isHolding ? 0.45 : 0.2), radius: viewModel.isHolding ? 20 : 10, y: 6)

            VStack(spacing: 6) {
                Image(systemName: viewModel.isHolding ? "waveform" : "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                Text(viewModel.isHolding ? "話してるニャ" : "押して話すニャ")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.bottom, 16)
        .opacity(isEnabled ? 1 : 0.4)
        .scaleEffect(viewModel.isHolding ? 1.08 : 1)
        .animation(.spring(duration: 0.25), value: viewModel.isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    if !viewModel.isHolding {
                        viewModel.beginHold()
                    }
                }
                .onEnded { _ in
                    if viewModel.isHolding {
                        viewModel.endHold()
                    }
                }
        )
        .sensoryFeedback(.impact, trigger: viewModel.isHolding)
    }

    private var holdButtonSize: CGFloat {
        viewModel.isHolding ? 148 : 132
    }

    private var holdButtonColor: Color {
        if !viewModel.isSessionActive || !viewModel.isConnected {
            return .gray
        }
        return viewModel.isHolding ? .red : .orange
    }
}

#Preview {
    InterpreterView()
}
