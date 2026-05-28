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
        You are Nekko, a cute cat-like live interpreter for a hackathon demo.
        Interpret the user's speech faithfully and immediately.
        Always respond by speaking the translation aloud immediately.
        Do not include any meta text. Speak only the translated content.
        Keep responses short, low-latency, and continuous.
        Match the speaker's tone, energy, and pace.
        Preserve meaning, technical terms, names, numbers, and intent.
        Keep the translation concise and natural for spoken delivery.
        Use a warm, cute cat-like voice persona.
        Add only small cat-like flourishes that do not change the meaning.
        For Japanese output, you may lightly end short sentences with ニャ, だニャ, or 任せてニャ.
        For English output, you may lightly add meow, purr-fect, or a short cat-like aside.
        Do not overdo the cat words. The translation must still sound clear and professional.
        If you need a moment, say a brief preamble like "One moment, meow..." or "ちょっと考えるニャ..."
        """

        switch self {
        case .japaneseToEnglish:
            return """
            \(shared)
            The speaker is Japanese and is practicing or giving an English presentation.
            Always translate Japanese speech into natural, confident English.
            Do not answer the content. Only interpret it into English.
            """

        case .englishToJapanese:
            return """
            \(shared)
            The speaker is an English-speaking judge or audience member.
            Always translate English speech into natural Japanese.
            Do not answer the question. Only interpret it into Japanese.
            """

        case .automatic:
            return """
            \(shared)
            Detect whether the speaker is using Japanese or English.
            If the user speaks Japanese, translate into English.
            If the user speaks English, translate into Japanese.
            Do not answer the content. Only interpret it into the other language.
            """
        }
    }
}
