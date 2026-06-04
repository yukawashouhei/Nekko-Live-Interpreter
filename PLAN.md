# Nekko Live Interpreter 実装プラン（現行）

本ドキュメントは、現在の Nekko アプリの実装方針・アーキテクチャ・機能一覧をまとめたものです。

---

## 1. 概要

- **アプリ名**: Nekko Live Interpreter
- **種別**: OpenAI Realtime API を利用した、日本語↔英語の音声対音声リアルタイム通訳 iOS アプリ
- **キャラクター**: 猫の「Nekko」が可愛い声と語尾で通訳音声を読み上げる
- **対応端末**: iPhone（実機・シミュレータ両対応）
- **バックエンド**: 不要。アプリ本体が **OpenAI Realtime API に直接 WebSocket 接続**

---

## 2. アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│  iOS App (Nekko)                                              │
│  ┌─────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │ 通訳タブ     │  │ 記録タブ          │  │ 設定タブ         ││
│  │ ・自動接続   │  │ ・記録タブ          │  │ ・OpenAIキー     ││
│  │ ・押して話す │  │                   │  │ ・About          ││
│  │ ・離して通訳 │  │                   │  │                  ││
│  └──────┬──────┘  └──────────────────┘  └─────────────────┘│
│         │                                                     │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  Services                                              │  │
│  │  OpenAIRealtimeInterpreterService (WebSocket)          │  │
│  │  AudioRecorderService (AVAudioEngine, PTT)             │  │
│  │  PCM16AudioPlayer (逐次再生)                            │  │
│  └──────┬─────────────────────────────────────────────────┘  │
│         │                                                     │
│  ┌──────▼──────┐                                             │
│  │ UserDefaults │  (OpenAI API Key)                          │
│  └─────────────┘                                             │
└─────────────────────────────────────────────────────────────┘
         │
         │  WSS
         ▼
┌─────────────────────────────────────────────────────────────┐
│  OpenAI Realtime API                                         │
│  wss://api.openai.com/v1/realtime?model=gpt-realtime         │
│  ・session.update (GA shape, voice=coral, 24kHz PCM16)       │
│  ・input_audio_buffer.append / commit                        │
│  ・response.create → response.output_audio.delta             │
└─────────────────────────────────────────────────────────────┘
```

- **認証**: 設定タブで入力した OpenAI API キーを `UserDefaults`（キー `nekko_openai_api_key`）に保存し、`Authorization: Bearer <key>` で接続。
- **バックエンド非依存**: 通訳はすべて iOS アプリから OpenAI Realtime API に直接接続。

---

## 3. 機能一覧

| 機能 | 説明 | 使用 API / 技術 |
|------|------|------------------|
| 自動接続 | 通訳タブ表示時に WebSocket を自動接続 | OpenAI Realtime (WebSocket), gpt-realtime |
| Push-to-Talk 通訳 | ボタンを押している間だけ録音、離した瞬間に通訳音声を再生 | input_audio_buffer.commit + response.create |
| 自動方向判定 | 日本語→英語 / 英語→日本語 を自動で判定 | direction = automatic（instructions） |
| 猫らしい発話 | 意味を保ちつつ可愛い声と軽い語尾（ニャ / meow） | session instructions |
| 逐次再生 | 翻訳音声をデルタ受信ごとに即再生 | PCM16AudioPlayer (AVAudioEngine) |
| 記録タブ | 録音・文字起こし履歴UI | SwiftData |
| ウィジェット | ホーム画面にドット絵の猫 | WidgetKit |

---

## 4. 主要コンポーネント

### 4.1 サービス層

- **OpenAIRealtimeInterpreterService**:
  - `wss://api.openai.com/v1/realtime?model=gpt-realtime`（フォールバック `gpt-4o-realtime-preview`）に WebSocket 接続。
  - `session.update`（GA shape: `type:"realtime"`, `output_modalities:["audio"]`, `audio.input/output`, `voice:"coral"`, 24kHz PCM16, `whisper-1`）。
  - Push-to-Talk: 既定で `turn_detection` を省略し、`commitTurn()` で `input_audio_buffer.commit` + `response.create`。拒否時は `server_vad`（silence 1500ms）にフォールバック。
  - voice は `coral` → `shimmer` → `marin` → `cedar` → `alloy` の順で自動フォールバック。
  - 受信: `session.created`, `response.output_audio.delta`（再生）, `response.output_audio_transcript.delta`, `error`。
  - 録音バッファは 24kHz モノ S16LE に変換して 20ms 単位で送信。

- **AudioRecorderService**: `AVAudioEngine` で録音。`isCapturing` フラグで PTT 中のみ音声バッファを送出。

- **PCM16AudioPlayer**: `AVAudioEngine` + `AVAudioPlayerNode` で 24kHz PCM16 をゲイン 2.0・スピーカー出力で逐次再生。

### 4.2 モデル / プロンプト

- **InterpreterDirection**（`japaneseToEnglish` / `englishToJapanese` / `automatic`）:
  - `instructions` で「一方向の通訳機」「会話応答禁止」「可愛い猫声」を指示。
  - few-shot 例で「翻訳して」等を会話ではなく通訳させる。
  - 現行UIでは `automatic` 固定で使用。

### 4.3 UI

- **通訳タブ（InterpreterView）**: Nekko の画像 + 大きなホールドボタンのミニマル構成。タブ表示で自動接続、ボタンを押している間だけ録音、離すと通訳。`onLongPressGesture(onPressingChanged:)` による Push-to-Talk。
- **記録タブ**: 録音・文字起こし履歴UI。
- **設定タブ**: OpenAI API キー入力、About。

---

## 5. 対応通訳

日本語 ↔ English（方向は `automatic` で自動判定）

---

## 6. 今後の拡張候補（未実装）

- 通訳履歴の保存・再生
- 方向の手動ロック（騒音下での誤判定対策）
- 複数言語対応（現状は日英）
- 翻訳テキストの画面表示オプション

---

*最終更新: 現行実装（OpenAI Realtime・Push-to-Talk・自動方向判定・猫プロンプト）に基づく*
