# Nekko Live Interpreter

> [English](./README.md) | [Français](./README.fr.md)

**OpenAI Realtime API** を活用した、猫のNekkoが日本語と英語を音声対音声で通訳してくれる iOS アプリ。日本語の発表を英語に、英語の質問を日本語に、可愛い猫らしい声と語尾でリアルタイム通訳します。

## 主な機能

- **ライブ音声通訳** — OpenAI Realtime API でマイク音声を低遅延に通訳し、翻訳音声を再生。
- **日本語 → 英語** — 日本語のピッチや発表を、自然な英語にしてNekkoが読み上げます。
- **英語 → 日本語** — 審査員の英語質問を、日本語に戻してNekkoが読み上げます。
- **猫らしい発話** — 日本語では「ニャ」、英語では “meow” など、意味を邪魔しない範囲で可愛い語尾を付けます。
- **手動方向切替** — デモ安定性のため `日→英` / `英→日` / `Auto` をすぐ切り替え可能。
- **記録タブ** — 既存の録音・文字起こし履歴UIは参考機能として残しています。
- **ウィジェット** — ホーム画面にドット絵の猫ウィジェット。

## OpenAI の利用箇所

| 機能 | モデル | API |
|------|--------|-----|
| ライブ音声通訳 | `gpt-realtime` | WebSocket `wss://api.openai.com/v1/realtime` |
| 音声入力 | PCM16 24kHz mono | `input_audio_buffer.append` |
| 音声出力 | PCM16 24kHz mono | `response.audio.delta` |
| 入力文字起こし | `whisper-1` | Realtime session transcription |

API 呼び出しは iOS アプリから OpenAI Realtime API に**直接接続**します。バックエンドサーバーは不要です。

## アーキテクチャ

```
iOS App (Nekko)
    ├── 通訳中: WebSocket → OpenAI Realtime (gpt-realtime)
    ├── 音声入力: AVAudioEngine → PCM16 24kHz mono
    ├── 音声出力: response.audio.delta → AVAudioEngine
    └── データ: UserDefaults（API キー）/ SwiftData（既存記録）
```

- **リアルタイム通訳**: 音声を 24kHz モノ PCM（S16LE）に変換し、WebSocket 送信。
- **猫プロンプト**: 翻訳の意味を保ちながら、Nekkoらしい短い語尾や相槌を追加。
- **デモ安定化**: 自動判定に加え、手動方向切替を用意。

## 使用技術

| 技術 | 用途 |
|------|------|
| SwiftUI | ユーザーインターフェース |
| SwiftData | データ永続化 |
| AVAudioEngine | 音声録音 |
| URLSessionWebSocketTask | Mistral リアルタイム文字起こし |
| OpenAI Realtime API | ライブ音声通訳 |
| URLSessionWebSocketTask | Realtime WebSocket 接続 |
| WidgetKit | ホーム画面ウィジェット |

## セットアップ

### 1. iOS アプリ

1. `Nekko.xcodeproj` を Xcode で開く。
2. Signing & Capabilities でチームを設定。
3. iPhone 実機またはシミュレータで実行。

### 2. OpenAI API キー

1. [OpenAI](https://platform.openai.com) で API キーを取得。
2. アプリ内の **設定** タブ → **OpenAI** → **OpenAI API キー** に入力。

API キーは端末内（UserDefaults）にのみ保存され、ライブ音声通訳に使用されます。

## ハッカソン用デモ手順

1. ヘッドフォンを接続します（スピーカー音声をマイクが拾う通訳ループを避けるため）。
2. **通訳** タブで `日→英` を選び、`通訳を始めるニャ` を押します。
3. 日本語でピッチを話します。Nekkoが英語音声で通訳します。
4. 審査員の質問時は `英→日` に切り替えます。
5. 英語の質問を聞かせると、Nekkoが日本語音声で通訳します。

### 3. ウィジェット（任意）

1. Xcode で File → New → Target → Widget Extension を選択。
2. Name を `NekkoWidget` にして作成。
3. 生成されたファイルを `NekkoWidget/` の既存ファイルで置き換え。

### 4. バックエンド（任意）

リポジトリには `NekkoBackend`（Vapor）が含まれていますが、**アプリの動作には不要**です。プロキシやログ用途でのみ利用できます。

```bash
cd NekkoBackend
export MISTRAL_API_KEY=your_key_here
swift run
```

## 対応言語

日本語, English, Français, العربية, Deutsch, Español, हिन्दी, Italiano, 한국어, Nederlands, Português, Русский, 中文

## ライセンス

Hackathon Project — Mistral AI Worldwide Hackathon 2026
