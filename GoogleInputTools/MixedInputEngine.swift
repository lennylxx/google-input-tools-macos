import Cocoa
import Carbon

struct InputSuggestion: Equatable {
    let text: String
    let consumed: Int
    let isEnglish: Bool
    let learningInput: String?
}

struct MixedCandidates {
    let suggestions: [InputSuggestion]
    let source: CandidateSource
}

/// Merges English completion and conservative pinyin typo recovery with the
/// existing cloud/cache ranking. All callbacks and state are on the main queue.
final class MixedInputEngine {
    static let shared = MixedInputEngine()
    private let cloud: CloudInputEngine
    private let correctionEngines: [CloudInputEngine]
    private let englishEngine: EnglishCompletionEngine
    private var requestID = UUID()

    init(cloud: CloudInputEngine = CloudInputEngine(),
         correctionEngines: [CloudInputEngine] = [CloudInputEngine(), CloudInputEngine()],
         english: EnglishCompletionEngine = .shared) {
        self.cloud = cloud
        self.correctionEngines = correctionEngines
        self.englishEngine = english
    }

    @discardableResult
    func request(_ text: String, scheme: InputTool, options: AccuracyOptions,
                 englishEnabled: Bool, typoEnabled: Bool,
                 complete: @escaping (MixedCandidates) -> Void) -> Bool {
        let id = UUID()
        requestID = id
        cloud.cancelPendingRequest()
        correctionEngines.forEach { $0.cancelPendingRequest() }
        let query = MixedInputQuery(text)
        let english = englishEnabled
            ? englishEngine.suggestions(for: text, limit: options.candidateCount)
            : EnglishSuggestions(candidates: [], prefersEnglish: false)
        let englishCandidates = english.candidates.map {
            InputSuggestion(text: $0, consumed: text.count, isEnglish: true, learningInput: nil)
        }
        if english.prefersEnglish || query.word.isEmpty {
            complete(MixedCandidates(suggestions: englishCandidates, source: .cache))
            return true
        }
        let corrections = typoEnabled && scheme == .Pinyin
            ? PinyinSpelling.typoCorrections(query.word, limit: correctionEngines.count) : []
        var raw: [InputSuggestion] = []
        var corrected = Array(repeating: [InputSuggestion](), count: corrections.count)
        var source: CandidateSource = .cache
        var remaining = 1 + corrections.count
        func finish() {
            remaining -= 1
            guard remaining == 0, self.requestID == id else { return }
            let values = Self.merge(raw: raw, corrected: corrected.flatMap { $0 },
                                    english: englishCandidates, limit: options.candidateCount)
            complete(MixedCandidates(suggestions: values, source: source))
        }
        cloud.requestCandidates(query.word, scheme: scheme, options: options) { words, lengths, origin in
            DispatchQueue.main.async {
                guard self.requestID == id else { return }
                if origin == .network { source = .network }
                raw = words.enumerated().map { index, word in
                    let consumed = lengths.flatMap { index < $0.count ? $0[index] : nil } ?? query.word.count
                    return InputSuggestion(text: query.prefix + word, consumed: query.prefix.count + consumed,
                        isEnglish: Self.isEnglish(word), learningInput: String(query.word.prefix(consumed)))
                }
                finish()
            }
        }
        for (index, correction) in corrections.enumerated() {
            correctionEngines[index].requestCandidates(correction, scheme: scheme, options: options) { words, lengths, origin in
                DispatchQueue.main.async {
                    guard self.requestID == id else { return }
                    if origin == .network { source = .network }
                    corrected[index] = Self.correctedSuggestions(words: words, lengths: lengths,
                        correction: correction, query: query)
                    finish()
                }
            }
        }
        return false
    }

    static func isEnglish(_ text: String) -> Bool {
        text.unicodeScalars.contains { (65...90).contains($0.value) || (97...122).contains($0.value) }
            && text.unicodeScalars.allSatisfy { $0.isASCII }
    }

    static func correctedSuggestions(words: [String], lengths: [Int]?, correction: String,
                                      query: MixedInputQuery) -> [InputSuggestion] {
        words.enumerated().compactMap { index, word in
            let length = lengths.flatMap { index < $0.count ? $0[index] : nil } ?? correction.count
            // A corrected query has different offsets: only a full match may
            // consume the original typo, otherwise trailing input could be lost.
            guard length == correction.count, !isEnglish(word) else { return nil }
            return InputSuggestion(text: query.prefix + word,
                consumed: query.prefix.count + query.word.count, isEnglish: false, learningInput: correction)
        }.prefix(2).map { $0 }
    }

    static func merge(raw: [InputSuggestion], corrected: [InputSuggestion],
                      english: [InputSuggestion], limit: Int) -> [InputSuggestion] {
        var result = [InputSuggestion]()
        var indices = [String: Int]()
        func append(_ item: InputSuggestion) {
            if let index = indices[item.text] {
                // Keep the full corrected consumption when the cloud only
                // matched a prefix of the typo for the very same candidate.
                if item.consumed > result[index].consumed { result[index] = item }
            } else {
                indices[item.text] = result.count
                result.append(item)
            }
        }
        // Preserve the original first choice. Typo alternatives and English are
        // visible on page one without replacing a valid Chinese first choice.
        raw.prefix(1).forEach(append)
        corrected.prefix(3).forEach(append)
        raw.dropFirst().prefix(2).forEach(append)
        english.prefix(4).forEach(append)
        raw.dropFirst(3).forEach(append)
        english.dropFirst(4).forEach(append)
        return Array(result.prefix(limit))
    }
}

/// Key policy shared by the IMK controller and native-text integration tests.
/// Normal Chinese selection remains in the controller's existing key handler.
enum MixedKeyAction: Equatable {
    case passThrough
    case acceptEnglish(Int)
    case insertEnglishSpace
    case finishLiteral(consumeKey: Bool)
    case none

    static func resolve(event: NSEvent, context: InputContext) -> MixedKeyAction {
        guard event.type == .keyDown, !Utilities.isApplicationShortcut(event.modifierFlags) else { return .none }
        // Explicit English mode retains the original literal keyboard behavior.
        // Word completion is available in mixed mode, alongside Chinese input.
        if context.isEnglishMode { return .passThrough }
        if event.keyCode == kVK_Tab {
            if event.modifierFlags.contains(.shift) { return .finishLiteral(consumeKey: false) }
            if let index = context.currentCandidateIsEnglish ? context.currentIndex : context.englishCandidateIndices.min() {
                return .acceptEnglish(index)
            }
            return .finishLiteral(consumeKey: false)
        }
        guard context.continuesEnglishOnSpace else { return .none }
        if event.keyCode == kVK_Space { return .insertEnglishSpace }
        if [kVK_LeftArrow, kVK_RightArrow, kVK_Return, kVK_Escape].contains(Int(event.keyCode)) {
            return .finishLiteral(consumeKey: event.keyCode == kVK_Escape)
        }
        if let key = event.characters?.first, event.keyCode != kVK_Delete &&
            !key.isLetter && !key.isNumber && key != "'" &&
            event.keyCode != kVK_UpArrow && event.keyCode != kVK_DownArrow {
            return .finishLiteral(consumeKey: false)
        }
        return .none
    }
}
