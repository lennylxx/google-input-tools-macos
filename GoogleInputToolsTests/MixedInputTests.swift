import Cocoa
import InputMethodKit
import XCTest
@testable import GoogleInputTools

class MixedInputTests: XCTestCase {
    func testPhraseCompletionUsesEarlierWords() {
        let engine = EnglishCompletionEngine(words: { _ in ["could", "count", "council"] })
        let result = engine.suggestions(for: "british cou")
        XCTAssertEqual(result.candidates.first, "British Council")
        XCTAssertTrue(result.prefersEnglish)
        XCTAssertEqual(engine.suggestions(for: "please visit british cou").candidates.first,
                       "please visit British Council")
        XCTAssertEqual(engine.suggestions(for: "united kin").candidates.first, "United Kingdom")
        XCTAssertEqual(engine.suggestions(for: "machine lear").candidates.first, "machine learning")
    }

    func testGeneralWordCompletionAndPinyinAmbiguity() {
        let engine = EnglishCompletionEngine(words: { word in
            ["configuration", "environment", "ship", "can"].filter { $0.hasPrefix(word) }
        })
        XCTAssertEqual(engine.suggestions(for: "configu").candidates, ["configuration"])
        XCTAssertTrue(engine.suggestions(for: "configu").prefersEnglish)
        XCTAssertFalse(engine.suggestions(for: "shi").prefersEnglish)
        XCTAssertFalse(engine.suggestions(for: "can").prefersEnglish)
        XCTAssertTrue(engine.suggestions(for: "hello can").prefersEnglish)
    }

    func testSystemDictionaryIncludesEnglishWordsAndProperNouns() {
        let engine = EnglishCompletionEngine()
        XCTAssertTrue(engine.suggestions(for: "configu").candidates.contains("configuration"))
        XCTAssertTrue(engine.suggestions(for: "british").candidates.contains("British"))
        XCTAssertEqual(engine.suggestions(for: "british cou").candidates.first, "British Council")
        for typo in ["nihoa", "zhogn", "nhiao", "niho"] {
            XCTAssertFalse(engine.suggestions(for: typo).prefersEnglish, "Must not mistake \(typo) for English")
        }
    }

    func testEnglishPrefixAndCapitalizationArePreserved() {
        let engine = EnglishCompletionEngine(words: { _ in ["configuration"] })
        XCTAssertEqual(engine.suggestions(for: "CONFIGU").candidates.first, "CONFIGURATION")
        XCTAssertEqual(engine.suggestions(for: "my configu").candidates.first, "my configuration")
        XCTAssertTrue(engine.suggestions(for: "中文configu").candidates.isEmpty)
    }

    func testFullPinyinAndIncompleteSyllableRecognition() {
        for input in ["nihao", "shijie", "zhongguo", "xi'an", "can", "shi", "nv", "lve", "zhongw", "zhongwen", "nis"] {
            XCTAssertTrue(PinyinSpelling.isPinyin(input), input)
        }
        for input in ["british", "configu", "nihoa", "zhogn", "nhiao", "hello"] {
            XCTAssertFalse(PinyinSpelling.isPinyin(input), input)
        }
    }

    func testTransposedAndMissingLettersHaveUsefulCorrections() {
        XCTAssertEqual(PinyinSpelling.typoCorrections("nihoa").first, "nihao")
        XCTAssertEqual(PinyinSpelling.typoCorrections("zhogn").first, "zhong")
        XCTAssertEqual(PinyinSpelling.typoCorrections("nhiao").first, "nihao")
        XCTAssertEqual(PinyinSpelling.typoCorrections("niho").first, "nihao")
        XCTAssertTrue(PinyinSpelling.typoCorrections("nihao").isEmpty)
        XCTAssertTrue(PinyinSpelling.typoCorrections("zhong").isEmpty)
        XCTAssertTrue(PinyinSpelling.typoCorrections("sh").isEmpty)
    }

    func testCorrectedCandidatesConsumeOriginalTypoWithoutLeavingLetters() {
        let values = MixedInputEngine.correctedSuggestions(words: ["你好", "你"], lengths: [5, 2],
            correction: "nihao", query: MixedInputQuery("British niho"))
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0].text, "British 你好")
        XCTAssertEqual(values[0].consumed, "British niho".count)
        XCTAssertEqual(values[0].learningInput, "nihao")
    }

    func testMergeKeepsChineseFirstAndUpgradesPartialConsumption() {
        let raw = [InputSuggestion(text: "你好哦啊", consumed: 5, isEnglish: false, learningInput: "nihoa"),
                   InputSuggestion(text: "你好", consumed: 3, isEnglish: false, learningInput: "nih")]
        let corrected = [InputSuggestion(text: "你好", consumed: 5, isEnglish: false, learningInput: "nihao")]
        let result = MixedInputEngine.merge(raw: raw, corrected: corrected,
            english: [InputSuggestion(text: "hello", consumed: 5, isEnglish: true, learningInput: nil)], limit: 20)
        XCTAssertEqual(result.first?.text, "你好哦啊")
        XCTAssertEqual(result[1], corrected[0])
        XCTAssertEqual(result.filter { $0.text == "你好" }.count, 1)
        XCTAssertTrue(result.contains { $0.isEnglish })
    }

    func testRequestCombinesTypoResponsesAndRejectsOlderRequests() {
        let (engine, session, cache) = makeEngine()
        defer { session.invalidateAndCancel(); cache.close() }
        let result = expectation(description: "current typo candidates")
        engine.request("nihoa", scheme: .Pinyin, options: AccuracyOptions(), englishEnabled: false,
                       typoEnabled: true) { _ in
            XCTFail("Cancelled revision must not deliver")
        }
        engine.request("niho", scheme: .Pinyin, options: AccuracyOptions(), englishEnabled: false,
                       typoEnabled: true) { batch in
            XCTAssertEqual(batch.suggestions.first?.text, "原始候选")
            let corrected = batch.suggestions.first { $0.text == "你好" }
            XCTAssertEqual(corrected?.consumed, 4)
            XCTAssertEqual(corrected?.learningInput, "nihao")
            result.fulfill()
        }
        wait(for: [result], timeout: 5)
    }

    func testDisabledFeaturesKeepOriginalCandidatePipeline() {
        let (engine, session, cache) = makeEngine()
        defer { session.invalidateAndCancel(); cache.close() }
        let done = expectation(description: "original candidates")
        engine.request("niho", scheme: .Pinyin, options: AccuracyOptions(), englishEnabled: false,
                       typoEnabled: false) { batch in
            XCTAssertEqual(batch.suggestions.map(\.text), ["原始候选"])
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testScreenshotInputsKeepChineseAlongsideEnglishCompletion() {
        let (engine, session, cache) = makeEngine(english: EnglishCompletionEngine(words: {
            $0 == "nis" ? ["nisei"] : []
        }))
        defer { session.invalidateAndCancel(); cache.close() }
        for (input, expected) in [("nis", "你是"), ("zhongwen", "中文")] {
            let done = expectation(description: input)
            let continuesEnglish = engine.request(input, scheme: .Pinyin, options: AccuracyOptions(),
                englishEnabled: true, typoEnabled: true) { batch in
                XCTAssertEqual(batch.suggestions.first?.text, expected)
                XCTAssertEqual(batch.suggestions.first?.isEnglish, false)
                XCTAssertEqual(batch.suggestions.first?.consumed, input.count)
                if input == "nis" { XCTAssertTrue(batch.suggestions.contains { $0.text == "nisei" && $0.isEnglish }) }
                done.fulfill()
            }
            XCTAssertFalse(continuesEnglish, "Space must select Chinese for \(input)")
            wait(for: [done], timeout: 5)
        }
    }

    func testEnglishPhraseFollowedByPinyinDoesNotStayInEnglish() {
        let (engine, session, cache) = makeEngine(english: EnglishCompletionEngine())
        defer { session.invalidateAndCancel(); cache.close() }
        let phrase = expectation(description: "English phrase")
        XCTAssertTrue(engine.request("british cou", scheme: .Pinyin, options: AccuracyOptions(),
            englishEnabled: true, typoEnabled: true) { batch in
            XCTAssertEqual(batch.suggestions.first?.text, "British Council")
            phrase.fulfill()
        })
        wait(for: [phrase], timeout: 5)
        // Exercise every prefix with the real system dictionary: no intermediate
        // English completion may latch the next composition into English mode.
        for length in 1..."zhongwen".count {
            let input = String("zhongwen".prefix(length))
            let done = expectation(description: input)
            XCTAssertFalse(engine.request(input, scheme: .Pinyin, options: AccuracyOptions(),
                englishEnabled: true, typoEnabled: true) { batch in
                XCTAssertFalse(batch.suggestions.isEmpty)
                XCTAssertEqual(batch.suggestions.first?.isEnglish, false)
                if input == "zhongwen" { XCTAssertEqual(batch.suggestions.first?.text, "中文") }
                done.fulfill()
            })
            wait(for: [done], timeout: 5)
        }
    }

    func testEnglishMetadataIsClearedWithCompositionRevision() {
        let context = InputContext()
        context.composeString = "british cou"
        let revision = context.revision
        XCTAssertTrue(context.acceptSuggestions([InputSuggestion(text: "British Council", consumed: 11,
            isEnglish: true, learningInput: nil)], source: .cache, revision: revision))
        XCTAssertTrue(context.currentCandidateIsEnglish)
        context.continuesEnglishOnSpace = true
        context.composeString = "nihao"
        XCTAssertFalse(context.currentCandidateIsEnglish)
        XCTAssertFalse(context.continuesEnglishOnSpace)
        XCTAssertTrue(context.candidateLearningInputs.isEmpty)
        XCTAssertFalse(context.acceptSuggestions([], source: .cache, revision: revision))
    }

    private func makeEngine(english: EnglishCompletionEngine = EnglishCompletionEngine(words: { _ in [] })) -> (MixedInputEngine, URLSession, CandidateCache) {
        let cache = CandidateCache(databasePath: ":memory:")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MixedCandidateProtocol.self]
        let session = URLSession(configuration: config)
        let engine = MixedInputEngine(cloud: CloudInputEngine(cache: cache, session: session),
            correctionEngines: [CloudInputEngine(cache: cache, session: session), CloudInputEngine(cache: cache, session: session)],
            english: english)
        return (engine, session, cache)
    }
}

private final class MixedCandidateProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let text = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "text" }!.value!
        let words = ["nihao": ["你好"], "nis": ["你是"], "zhongwen": ["中文"]][text] ?? ["原始候选"]
        let json: [Any] = ["SUCCESS", [[text, words, [], ["matched_length": [text.count]]]]]
        let data = try! JSONSerialization.data(withJSONObject: json)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}


class MixedKeyActionTests: XCTestCase {
    private let context = InputContext(pageSize: 9)
    private let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 140))
    private let english = EnglishCompletionEngine()

    override func setUp() {
        super.setUp()
        context.clean()
        context.isEnglishMode = false
        _ = textView.layoutManager
        textView.string = "我想联系 "
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
    }

    private func action(_ characters: String, code: Int, modifiers: NSEvent.ModifierFlags = []) -> MixedKeyAction {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: UInt16(code))!
        return MixedKeyAction.resolve(event: event, context: context)
    }

    private func type(_ text: String) {
        for character in text {
            if character == " " { XCTAssertEqual(action(" ", code: kVK_Space), .insertEnglishSpace) }
            context.composeString.append(character)
            let composition = CompositionText(string: context.composeString)
            textView.setMarkedText(composition.string, selectedRange: composition.selectionRange,
                                   replacementRange: composition.replacementRange)
            let result = english.suggestions(for: context.composeString)
            context.continuesEnglishOnSpace = result.prefersEnglish
            context.acceptSuggestions(result.candidates.map {
                InputSuggestion(text: $0, consumed: context.composeString.count, isEnglish: true, learningInput: nil)
            }, source: .cache, revision: context.revision)
        }
    }

    func testMixedPhraseSpaceAndTabAgainstNativeTextStorage() {
        type("british cou")
        XCTAssertEqual(context.composeString, "british cou")
        XCTAssertEqual(textView.string, "我想联系 british cou")
        XCTAssertEqual(action("\t", code: kVK_Tab), .acceptEnglish(0))
        XCTAssertEqual(context.candidates.first, "British Council")
        textView.insertText(context.candidates[0], replacementRange: NSRange(location: NSNotFound, length: 0))
        context.clean()
        XCTAssertEqual(textView.string, "我想联系 British Council")
        XCTAssertFalse(textView.hasMarkedText())
        type("nihao")
        context.acceptCandidates(["你好"], matchedLength: [5], source: .cache, revision: context.revision)
        XCTAssertEqual(action(" ", code: kVK_Space), .none, "Normal Chinese Space selection must remain active")
        textView.insertText(context.candidates[0], replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(textView.string, "我想联系 British Council你好")
    }

    func testShiftTabAndShortcutsNeverAcceptCompletion() {
        type("british cou")
        XCTAssertEqual(action("\t", code: kVK_Tab, modifiers: .shift), .finishLiteral(consumeKey: false))
        XCTAssertEqual(action("c", code: kVK_ANSI_C, modifiers: .command), .none)
        XCTAssertEqual(action("v", code: kVK_ANSI_V, modifiers: .command), .none)
        XCTAssertEqual(action("\t", code: kVK_Tab, modifiers: .control), .none)
    }

    func testExplicitEnglishModePassesKeysThroughAndMixedModeResumesChineseSelection() {
        context.isEnglishMode = true
        for character in "niszhongwen" {
            XCTAssertEqual(action(String(character), code: kVK_ANSI_N), .passThrough)
        }
        for (text, keyCode) in [(" ", kVK_Space), ("\t", kVK_Tab), ("\r", kVK_Return), ("1", kVK_ANSI_1)] {
            XCTAssertEqual(action(text, code: keyCode), .passThrough)
        }
        XCTAssertTrue(context.composeString.isEmpty)
        XCTAssertFalse(textView.hasMarkedText())

        context.isEnglishMode = false
        type("zhongwen")
        context.acceptSuggestions([InputSuggestion(text: "中文", consumed: 8, isEnglish: false,
            learningInput: "zhongwen")], source: .cache, revision: context.revision)
        XCTAssertEqual(action(" ", code: kVK_Space), .none)
        textView.insertText(context.candidates[0], replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(textView.string, "我想联系 中文")
    }

    func testEnglishEnterAndPunctuationPassThroughButEscapeKeepsText() {
        type("british cou")
        XCTAssertEqual(action("\r", code: kVK_Return), .finishLiteral(consumeKey: false))
        XCTAssertEqual(action(".", code: kVK_ANSI_Period), .finishLiteral(consumeKey: false))
        XCTAssertEqual(action("\u{1b}", code: kVK_Escape), .finishLiteral(consumeKey: true))
        XCTAssertEqual(action("", code: kVK_LeftArrow), .finishLiteral(consumeKey: false))
        XCTAssertEqual(action("", code: kVK_Delete), .none)
        textView.insertText(context.composeString, replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(textView.string, "我想联系 british cou")
    }

    func testEnglishTabFindsMixedCandidateWithoutChangingChineseFirstChoice() {
        context.composeString = "shi"
        context.acceptSuggestions([
            InputSuggestion(text: "是", consumed: 3, isEnglish: false, learningInput: "shi"),
            InputSuggestion(text: "ship", consumed: 3, isEnglish: true, learningInput: nil)
        ], source: .cache, revision: context.revision)
        XCTAssertEqual(context.currentIndex, 0)
        XCTAssertEqual(action(" ", code: kVK_Space), .none)
        XCTAssertEqual(action("\t", code: kVK_Tab), .acceptEnglish(1))
    }
}
