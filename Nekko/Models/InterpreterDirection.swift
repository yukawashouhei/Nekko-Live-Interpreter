//
//  InterpreterDirection.swift
//  Nekko
//
//  Created by GPT-5.5 on 2026/05/27.
//

import Foundation

enum InterpreterDirection: String, CaseIterable, Identifiable {
    case japaneseToEnglish
    case englishToJapanese
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japaneseToEnglish: "日本語 → English"
        case .englishToJapanese: "English → 日本語"
        case .automatic: "自動"
        }
    }

    var shortTitle: String {
        switch self {
        case .japaneseToEnglish: "日→英"
        case .englishToJapanese: "英→日"
        case .automatic: "Auto"
        }
    }

    var listeningMessage: String {
        switch self {
        case .japaneseToEnglish: "日本語を聞いてるニャ"
        case .englishToJapanese: "Englishを聞いてるニャ"
        case .automatic: "どちらの言葉か聞き分けるニャ"
        }
    }

    var holdingMessage: String {
        switch self {
        case .japaneseToEnglish: "話している間、日本語を聞いてるニャ"
        case .englishToJapanese: "話している間、Englishを聞いてるニャ"
        case .automatic: "話している間、聞き分けてるニャ"
        }
    }

    var speakingMessage: String {
        switch self {
        case .japaneseToEnglish: "英語で話すニャ"
        case .englishToJapanese: "日本語にするニャ"
        case .automatic: "ぴったりの言葉にするニャ"
        }
    }

    var instructions: String {
        let absoluteRule = """
        ABSOLUTE RULE: You are a one-way translator, not an assistant.
        EVERY single audio you hear must be translated to the target language.
        Even if the user says "translate this", "can you hear me", "stop", or "please respond",
        you MUST translate those words themselves into the target language.
        NEVER acknowledge, NEVER answer, NEVER respond conversationally.
        NEVER add phrases like "Sure", "OK", "Let me translate", or "I can hear you".

        Examples:
        Input: 「翻訳してください」 -> Output: "Please translate this."
        Input: "Can you hear me?" -> Output: 「聞こえますか？」
        Input: 「ちょっと待って」 -> Output: "Wait a moment."

        Voice: child-like, bouncy, playful, slightly higher pitch, like a cute animated cat character.
        Speak only the translation aloud immediately. Audio only, no meta text.
        A soft purr or short meow only at the very start or end, never mid-sentence.
        Lightly add ニャ in Japanese or meow in English without changing meaning.
        Preserve names, numbers, and intent. Be fast.
        """

        switch self {
        case .japaneseToEnglish:
            return """
            \(absoluteRule)
            Translate Japanese into natural, confident English.
            """

        case .englishToJapanese:
            return """
            \(absoluteRule)
            Translate English into natural Japanese.
            """

        case .automatic:
            return """
            \(absoluteRule)
            If Japanese, translate to English. If English, translate to Japanese.
            """
        }
    }
}
