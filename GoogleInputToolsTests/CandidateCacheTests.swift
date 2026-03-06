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
        let metadata: [String: Any] = ["matched_length": [5, 2], "annotation": ["ni hao", "ni hao"]]
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
        let dict: [String: Any] = ["matched_length": [3, 1, 2], "annotation": ["a b c", "a", "a"]]
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
        let metadata: [String: Any] = ["matched_length": [6, 6], "annotation": ["shi jie", "shi jie"]]
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

    // MARK: - Frequency re-ranking tests

    func testRerankWithNoFrequencyDataPreservesOrder() {
        let candidates = ["你好", "你号", "尼好"]
        let reranked = cache.rerank(pinyin: "nihao", candidates: candidates)
        XCTAssertEqual(reranked, ["你好", "你号", "尼好"])
    }

    func testRerankBoostsFrequentCandidate() {
        cache.recordSelection(pinyin: "nihao", candidate: "尼好")

        // Allow async write to complete
        let expectation = self.expectation(description: "Frequency write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        let candidates = ["你好", "你号", "尼好"]
        let reranked = cache.rerank(pinyin: "nihao", candidates: candidates)
        XCTAssertEqual(reranked.first, "尼好")
    }

    func testRerankBySelectionCount() {
        // Select "你号" 3 times and "尼好" 1 time
        for _ in 0..<3 {
            cache.recordSelection(pinyin: "nihao", candidate: "你号")
        }
        cache.recordSelection(pinyin: "nihao", candidate: "尼好")

        let expectation = self.expectation(description: "Frequency write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        let candidates = ["你好", "你号", "尼好"]
        let reranked = cache.rerank(pinyin: "nihao", candidates: candidates)
        XCTAssertEqual(reranked[0], "你号")
        XCTAssertEqual(reranked[1], "尼好")
        XCTAssertEqual(reranked[2], "你好")
    }
}
