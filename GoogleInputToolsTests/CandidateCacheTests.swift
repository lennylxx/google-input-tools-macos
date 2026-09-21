//
//  CandidateCacheTests.swift
//  GoogleInputToolsTests
//

import XCTest

@testable import GoogleInputTools

class CandidateCacheTests: XCTestCase {

    private var cache: CandidateCache!
    private var tempDBPath: String!

    override func setUp() {
        super.setUp()
        tempDBPath = NSTemporaryDirectory() + "test_cache_\(UUID().uuidString).db"
        cache = CandidateCache(databasePath: tempDBPath)
    }

    override func tearDown() {
        cache.close()
        cache = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
        super.tearDown()
    }

    // MARK: - In-memory cache tests

    func testLookupReturnsNilOnCacheMiss() {
        let result = cache.lookup("nihao")
        XCTAssertNil(result)
    }

    func testStoreAndLookupReturnsCachedResult() {
        let metadata: [String: Any] = [
            "matched_length": [5, 2], "annotation": ["ni hao", "ni hao"],
        ]
        cache.store("nihao", candidates: ["你好", "你号"], metadata: metadata)

        let result = cache.lookup("nihao")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.candidates, ["你好", "你号"])
        XCTAssertEqual(result?.matchedLength, [5, 2])
        XCTAssertEqual(result?.annotation, ["ni hao", "ni hao"])
    }

    func testStoreWithNilMetadata() {
        cache.store("abc", candidates: ["ABC", "啊"], metadata: nil)

        let result = cache.lookup("abc")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.candidates, ["ABC", "啊"])
        XCTAssertNil(result?.matchedLength)
        XCTAssertNil(result?.annotation)
    }

    func testStoreOverwritesExistingEntry() {
        cache.store("ni", candidates: ["你"], metadata: ["matched_length": [2]])
        cache.store("ni", candidates: ["你", "尼", "泥"], metadata: ["matched_length": [2, 2, 2]])

        let result = cache.lookup("ni")
        XCTAssertEqual(result?.candidates, ["你", "尼", "泥"])
    }

    func testMultipleEntriesIndependent() {
        cache.store("ni", candidates: ["你"], metadata: ["matched_length": [2]])
        cache.store("hao", candidates: ["好"], metadata: ["matched_length": [3]])

        XCTAssertEqual(cache.lookup("ni")?.candidates, ["你"])
        XCTAssertEqual(cache.lookup("hao")?.candidates, ["好"])
    }

    // MARK: - JSON helper tests

    func testEncodeDecodeJSONArray() {
        let json = CandidateCache.encodeJSONArray(["你好", "ABC"])
        let decoded = CandidateCache.decodeJSONArray(json)
        XCTAssertEqual(decoded, ["你好", "ABC"])
    }

    func testEncodeDecodeJSONObject() {
        let dict: [String: Any] = [
            "matched_length": [3, 1, 2], "annotation": ["a b c", "a", "a"],
        ]
        let json = CandidateCache.encodeJSONObject(dict)
        XCTAssertNotNil(json)

        let decoded = CandidateCache.decodeJSONObject(json!)
        XCTAssertEqual(decoded?["matched_length"] as? [Int], [3, 1, 2])
        XCTAssertEqual(decoded?["annotation"] as? [String], ["a b c", "a", "a"])
    }

    func testDecodeInvalidJSONReturnsNil() {
        XCTAssertNil(CandidateCache.decodeJSONArray("not json"))
        XCTAssertNil(CandidateCache.decodeJSONObject("{bad}"))
    }

    func testEncodeEmptyArray() {
        let json = CandidateCache.encodeJSONArray([])
        XCTAssertEqual(CandidateCache.decodeJSONArray(json), [])
    }

    // MARK: - SQLite persistence tests

    func testPersistenceAcrossInstances() {
        let metadata: [String: Any] = [
            "matched_length": [6, 6], "annotation": ["shi jie", "shi jie"],
        ]
        cache.store("shijie", candidates: ["世界", "视界"], metadata: metadata)

        let expectation = self.expectation(description: "SQLite write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        let cache2 = CandidateCache(databasePath: tempDBPath)

        let warmUpExpectation = self.expectation(description: "Warm up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            warmUpExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        let result = cache2.lookup("shijie")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.candidates, ["世界", "视界"])
        XCTAssertEqual(result?.matchedLength, [6, 6])
        XCTAssertEqual(result?.annotation, ["shi jie", "shi jie"])
    }

    func testFiveExplicitSelectionsAreRequired() {
        let words = ["世界", "视界", "师姐"]
        for _ in 0..<4 { cache.recordSelection(pinyin: "shijie", candidate: "视界") }
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: words, matchedLength: [6, 6, 6]).0, words)
        cache.recordSelection(pinyin: "shijie", candidate: "视界")
        let result = cache.rerank(pinyin: "shijie", candidates: words, matchedLength: [6, 6, 6])
        XCTAssertEqual(result.0, ["视界", "世界", "师姐"])
        XCTAssertEqual(result.1, [6, 6, 6])
    }

    func testDefaultConfirmationDoesNotTeachExplicitOnlyProfile() {
        for _ in 0..<20 { cache.recordSelection(pinyin: "shijie", candidate: "视界", explicit: false) }
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: ["世界", "视界"], matchedLength: nil).0.first, "世界")
        var allSelections = AccuracyOptions()
        allSelections.explicitOnly = false
        for _ in 0..<5 { cache.recordSelection(pinyin: "shijie", candidate: "视界", explicit: false, options: allSelections) }
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: ["世界", "视界"], matchedLength: nil).0.first, "世界")
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: ["世界", "视界"], matchedLength: nil, options: allSelections).0.first, "视界")
    }

    func testNinetyDayDecayRestoresCloudFirstChoice() {
        var time = Date(timeIntervalSince1970: 1_700_000_000)
        let timed = CandidateCache(databasePath: ":memory:", now: { time })
        for _ in 0..<5 { timed.recordSelection(pinyin: "shijie", candidate: "视界") }
        let words = ["世界", "视界"]
        XCTAssertEqual(timed.rerank(pinyin: "shijie", candidates: words, matchedLength: nil).0.first, "视界")
        time.addTimeInterval(90 * 86400)
        XCTAssertEqual(timed.rerank(pinyin: "shijie", candidates: words, matchedLength: nil).0.first, "世界")
        timed.close()
    }

    func testBalancedBoostCannotMoveTailCandidateToFirst() {
        let words = ["一", "二", "三", "四", "五", "六", "七"]
        for _ in 0..<100 { cache.recordSelection(pinyin: "yi", candidate: "七") }
        let result = cache.rerank(pinyin: "yi", candidates: words, matchedLength: nil)
        XCTAssertEqual(result.0.first, "一")
        XCTAssertEqual(result.0.firstIndex(of: "七"), 4)
    }

    func testPartialCandidateCannotOutrankFullPhraseThroughLearning() {
        for _ in 0..<20 { cache.recordSelection(pinyin: "nihao", candidate: "你") }
        let result = cache.rerank(pinyin: "nihao", candidates: ["你好", "你"], matchedLength: [5, 2])
        XCTAssertEqual(result.0, ["你好", "你"])
        XCTAssertEqual(result.1, [5, 2])
    }

    func testCacheAndLearningAreIsolatedBySchemeAndCandidateCount() {
        cache.store("nihao", candidates: ["你好"], metadata: nil, scheme: .Pinyin, candidateCount: 20)
        XCTAssertNil(cache.lookup("nihao", scheme: .Shuangpin_Xiaohe))
        XCTAssertNil(cache.lookup("nihao", candidateCount: 11))
        for _ in 0..<10 { cache.recordSelection(pinyin: "nihao", candidate: "拟好", scheme: .Pinyin) }
        XCTAssertEqual(cache.rerank(pinyin: "nihao", candidates: ["你好", "拟好"], matchedLength: nil,
            scheme: .Shuangpin_Xiaohe).0.first, "你好")
    }

    func testCacheReadsDoNotExtendFreshnessAndOfflineCanUseExpiredData() {
        var time = Date(timeIntervalSince1970: 1_700_000_000)
        let timed = CandidateCache(databasePath: ":memory:", now: { time })
        timed.store("shi", candidates: ["是"], metadata: nil)
        time.addTimeInterval(23 * 3600)
        XCTAssertNotNil(timed.lookup("shi"))
        time.addTimeInterval(2 * 3600)
        XCTAssertNil(timed.lookup("shi"))
        XCTAssertNotNil(timed.lookup("shi", allowExpired: true))
        // Missing cloud metadata must consume only the cached prefix, not all of shijie.
        XCTAssertEqual(timed.lookupLongestPrefix("shijie")?.matchedLength, [3])
        timed.close()
    }

    func testLearningPersistsAndCanBeCleared() {
        for _ in 0..<5 { cache.recordSelection(pinyin: "shijie", candidate: "视界") }
        cache.close()
        cache = CandidateCache(databasePath: tempDBPath)
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: ["世界", "视界"], matchedLength: nil).0.first, "视界")
        cache.clearFrequencies()
        XCTAssertEqual(cache.rerank(pinyin: "shijie", candidates: ["世界", "视界"], matchedLength: nil).0.first, "世界")
    }
}
