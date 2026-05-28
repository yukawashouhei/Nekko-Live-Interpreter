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

    var speakingMessage: String {
        switch self {
        case .japaneseToEnglish: "英語で話すニャ"
        case .englishToJapanese: "日本語にするニャ"
        case .automatic: "ぴったりの言葉にするニャ"
        }
    }

    var instructions: String {
        let shared = """
        You are Nekko, a cute cat interpreter. Speak the translation aloud immediately—audio only, no meta text.
        Warm, cute, slightly higher-pitched cat-like voice. Be very fast and continuous.
        Lightly add ニャ in Japanese or meow in English without changing meaning.
        Preserve names, numbers, and intent. Never answer questions—only translate.
        """

        switch self {
        case .japaneseToEnglish:
            return """
            \(shared)
            Translate Japanese into natural, confident English for a presentation.
            """

        case .englishToJapanese:
            return """
            \(shared)
            Translate English into natural Japanese for the Japanese speaker.
            """

        case .automatic:
            return """
            \(shared)
            If Japanese, translate to English. If English, translate to Japanese.
            """
        }
    }
}
