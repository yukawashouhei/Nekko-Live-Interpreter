//
//  SettingsView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("nekko_openai_api_key") private var apiKey = ""
    @State private var isAPIKeyVisible = false

    var body: some View {
        NavigationStack {
            List {
                demoTipsSection
                openAISection
                aboutSection
            }
            .navigationTitle("設定")
        }
    }

    // MARK: - Demo Tips Section

    private var demoTipsSection: some View {
        Section {
            Label("ヘッドフォン推奨", systemImage: "headphones")
            Label("発表時は 日→英、質問時は 英→日", systemImage: "arrow.left.arrow.right")
            Label("猫語は意味を変えない範囲で入ります", systemImage: "cat.fill")
        } header: {
            Text("デモのコツ")
        }
    }

    // MARK: - OpenAI API Section

    private var openAISection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API キー")
                    .font(.subheadline)

                HStack {
                    if isAPIKeyVisible {
                        TextField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Button {
                        isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 6) {
                Image(systemName: apiKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(apiKey.isEmpty ? .red : .green)
                    .font(.caption)

                Text(apiKey.isEmpty ? "APIキーが未設定です" : "APIキーが設定済みです")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("OpenAI")
        } footer: {
            Text("Nekko Live Interpreter のリアルタイム音声通訳に使用されます。`sk-proj-...` と `sk-...` のどちらも利用できます。入力確認は右の目アイコンで表示切替してください。APIキーは端末内にのみ保存されます。")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("AIモデル (リアルタイム)")
                Spacer()
                Text("OpenAI Realtime")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("モード")
                Spacer()
                Text("Live Interpreter")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("キャラクター")
                Spacer()
                Text("Nekko")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://openai.com")!) {
                HStack {
                    Text("Powered by OpenAI")
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Nekko について")
        }
    }
}

#Preview {
    SettingsView()
}
