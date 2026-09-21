import Cocoa

struct MixedInputQuery {
    let prefix: String
    let word: String

    init(_ text: String) {
        if let space = text.lastIndex(of: " ") {
            prefix = String(text[...space])
            word = String(text[text.index(after: space)...])
        } else {
            prefix = ""
            word = text
        }
    }
}

struct EnglishSuggestions {
    let candidates: [String]
    let prefersEnglish: Bool
}

/// Uses the system's English dictionary locally. No typed text is sent to a
/// search engine or a separate prediction service.
final class EnglishCompletionEngine {
    static let shared = EnglishCompletionEngine()
    typealias WordProvider = (String) -> [String]
    private let words: (String, String) -> [String]

    init(words: WordProvider? = nil) {
        if let words = words {
            self.words = { word, _ in words(word) }
            return
        }
        self.words = { word, text in
            let prefix = MixedInputQuery(text).prefix
            func complete(_ value: String) -> [String] {
                NSSpellChecker.shared.completions(forPartialWordRange: NSRange(location: prefix.utf16.count, length: value.utf16.count),
                    in: prefix + value, language: "en", inSpellDocumentWithTag: 0) ?? []
            }
            let values = complete(word)
            // Proper nouns such as British are case-sensitive in the system dictionary.
            return values.isEmpty ? complete(word.prefix(1).uppercased() + word.dropFirst()) : values
        }
    }

    // Common collocations supplement word completion, especially proper names.
    // General word completion still comes from the full system dictionary.
    static let phrases = [
        "British Council", "British Columbia", "British Museum", "British Airways",
        "United Kingdom", "United States", "United Nations", "European Union",
        "New York", "New Zealand", "San Francisco", "Los Angeles", "Hong Kong",
        "South Korea", "South Africa", "North America", "South America",
        "good morning", "good afternoon", "good evening", "good night",
        "thank you", "thank you very much", "you are welcome", "nice to meet you",
        "best regards", "kind regards", "looking forward to", "as soon as possible",
        "by the way", "in other words", "for example", "of course", "no problem",
        "machine learning", "deep learning", "artificial intelligence", "natural language processing",
        "large language model", "neural network", "computer science", "data science",
        "source code", "open source", "pull request", "code review", "version control",
        "command line", "user interface", "user experience", "input method",
        "operating system", "file system", "error message", "unit test", "integration test",
        "real time", "access token", "application programming interface", "web development",
        "software engineering", "database connection", "network connection", "configuration file"
    ]

    func suggestions(for text: String, limit: Int = 12) -> EnglishSuggestions {
        let query = MixedInputQuery(text)
        guard text.count <= 160, text.unicodeScalars.allSatisfy({
            CharacterSet.letters.contains($0) && $0.isASCII || $0 == " " || $0 == "'" || $0 == "-"
        }) else { return EnglishSuggestions(candidates: [], prefersEnglish: false) }
        var candidates = [String]()
        var seen = Set<String>()
        func append(_ value: String) {
            guard value.lowercased().hasPrefix(text.lowercased()), seen.insert(value.lowercased()).inserted else { return }
            candidates.append(value)
        }
        // Match phrase prefixes at word boundaries, including later in a sentence.
        if text.contains(" ") {
            var starts = [text.startIndex]
            starts += text.indices.filter { text[$0] == " " }.map { text.index(after: $0) }
            for start in starts where start < text.endIndex {
                let suffix = String(text[start...])
                guard suffix.contains(" ") else { continue }
                for phrase in Self.phrases where phrase.lowercased().hasPrefix(suffix.lowercased()) {
                    append(String(text[..<start]) + phrase)
                }
            }
        }
        let phraseMatch = !candidates.isEmpty
        let completions = query.word.count >= 2 || ["a", "i"].contains(query.word.lowercased()) ? words(query.word, text) : []
        for word in completions {
            guard word.lowercased().hasPrefix(query.word.lowercased()) else { continue }
            let value = query.word.count > 1 && query.word == query.word.uppercased() ? word.uppercased() : word
            append(query.prefix + value)
        }
        let exactWord = completions.contains { $0.caseInsensitiveCompare(query.word) == .orderedSame }
        let prefersEnglish = phraseMatch ||
            (!completions.isEmpty && !PinyinSpelling.isPinyin(query.word)) ||
            (!query.prefix.isEmpty && exactWord)
        return EnglishSuggestions(candidates: Array(candidates.prefix(limit)), prefersEnglish: prefersEnglish)
    }
}
