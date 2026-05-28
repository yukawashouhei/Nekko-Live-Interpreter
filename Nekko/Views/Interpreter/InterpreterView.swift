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

                VStack(spacing: 0) {
                    Spacer()

                    catSection

                    if let status = viewModel.statusLine {
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(statusColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }

                    Spacer()

                    holdButton
                        .padding(.bottom, 48)
                }
            }
            .navigationTitle("Nekko Interpreter")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.checkPermissions()
                await viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
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

    private var catSection: some View {
        ZStack {
            Circle()
                .fill(.orange.opacity(0.18))
                .frame(width: 220, height: 220)
                .scaleEffect(isCatPulsing ? (pulseCat ? 1.08 : 0.96) : 1)

            Circle()
                .stroke(.orange.opacity(0.25), lineWidth: 2)
                .frame(width: 236, height: 236)

            Image("Cat\(currentCatIndex)")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .shadow(color: .orange.opacity(0.25), radius: 18, y: 8)
                .accessibilityLabel("Nekko")
        }
    }

    private var isCatPulsing: Bool {
        viewModel.isHolding || viewModel.isSpeaking
    }

    private var statusColor: Color {
        if viewModel.hasError {
            return .red
        }
        if !viewModel.isConnected {
            return .orange
        }
        return .secondary
    }

    private var holdButton: some View {
        let size: CGFloat = viewModel.isHolding ? 160 : 144

        return ZStack {
            Circle()
                .fill(holdButtonColor.gradient)
                .frame(width: size, height: size)
                .shadow(
                    color: .orange.opacity(viewModel.isHolding ? 0.45 : 0.2),
                    radius: viewModel.isHolding ? 20 : 10,
                    y: 6
                )

            VStack(spacing: 8) {
                Image(systemName: viewModel.isHolding ? "waveform" : "mic.fill")
                    .font(.system(size: 40, weight: .semibold))
                Text(viewModel.isHolding ? "話してるニャ" : "押して話すニャ")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
        .contentShape(Circle())
        .frame(width: size, height: size)
        .opacity(viewModel.isSessionActive ? 1 : 0.45)
        .scaleEffect(viewModel.isHolding ? 1.05 : 1)
        .animation(.spring(duration: 0.25), value: viewModel.isHolding)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            perform: {},
            onPressingChanged: { isPressing in
                if isPressing {
                    viewModel.beginHold()
                } else {
                    viewModel.endHold()
                }
            }
        )
        .sensoryFeedback(.impact, trigger: viewModel.isHolding)
    }

    private var holdButtonColor: Color {
        if !viewModel.isSessionActive {
            return .gray
        }
        return viewModel.isHolding ? .red : .orange
    }
}

#Preview {
    InterpreterView()
}
