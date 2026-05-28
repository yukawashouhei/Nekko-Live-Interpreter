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
                        controlButton
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
                    .scaleEffect(viewModel.isInterpreting ? (pulseCat ? 1.08 : 0.96) : 1)

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

            if viewModel.isInterpreting {
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
                Text(viewModel.isInterpreting ? "Listening, meow..." : "Ready")
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

    private var controlButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.toggleInterpreter()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isInterpreting ? "stop.fill" : "mic.fill")
                Text(viewModel.isInterpreting ? "通訳を止めるニャ" : "通訳を始めるニャ")
                    .fontWeight(.semibold)
            }
            .font(.title3)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.isInterpreting ? Color.red.gradient : Color.orange.gradient,
                in: RoundedRectangle(cornerRadius: 22)
            )
            .shadow(color: .orange.opacity(0.25), radius: 12, y: 6)
        }
        .disabled(!viewModel.permissionsGranted)
        .opacity(viewModel.permissionsGranted ? 1 : 0.55)
        .sensoryFeedback(.impact, trigger: viewModel.isInterpreting)
        .padding(.bottom, 16)
    }
}

#Preview {
    InterpreterView()
}
