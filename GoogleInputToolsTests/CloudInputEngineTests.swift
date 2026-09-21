import XCTest
@testable import GoogleInputTools

class CloudInputEngineTests: XCTestCase {

    private var savedProxyType: ProxyType!
    private var savedProxyHost: String!
    private var savedProxyPort: Int!

    override func setUp() {
        super.setUp()
        savedProxyType = ProxySettings.type
        savedProxyHost = ProxySettings.host
        savedProxyPort = ProxySettings.port
    }

    override func tearDown() {
        ProxySettings.type = savedProxyType
        ProxySettings.host = savedProxyHost
        ProxySettings.port = savedProxyPort
        super.tearDown()
    }

    // MARK: - parseResponse

    func testParseSuccessResponse() {
        let json: [Any] = [
            "SUCCESS",
            [[
                "nihao",
                ["你好", "你号", "尼好"],
                [],
                [
                    "annotation": ["ni hao", "ni hao", "ni hao"],
                    "candidate_type": [0, 0, 0],
                    "matched_length": [5, 5, 5]
                ]
            ]]
        ]

        let result = CloudInputEngine.parseResponse(json)
        XCTAssertNotNil(result)

        let (candidates, metadata) = result!
        XCTAssertEqual(candidates, ["你好", "你号", "尼好"])
        XCTAssertEqual(metadata?["matched_length"] as? [Int], [5, 5, 5])
        XCTAssertEqual(metadata?["annotation"] as? [String], ["ni hao", "ni hao", "ni hao"])
    }

    func testParsePartialMatchResponse() {
        let json: [Any] = [
            "SUCCESS",
            [[
                "abc",
                ["ABC", "啊", "阿", "阿布"],
                [],
                [
                    "matched_length": [3, 1, 1, 2]
                ]
            ]]
        ]

        let result = CloudInputEngine.parseResponse(json)
        XCTAssertNotNil(result)

        let (candidates, metadata) = result!
        XCTAssertEqual(candidates.count, 4)
        XCTAssertEqual(metadata?["matched_length"] as? [Int], [3, 1, 1, 2])
    }

    func testParseNoMatchedLength() {
        let json: [Any] = [
            "SUCCESS",
            [[
                "test",
                ["测试"],
                [],
                [String: Any]()  // empty meta
            ]]
        ]

        let result = CloudInputEngine.parseResponse(json)
        XCTAssertNotNil(result)

        let (candidates, metadata) = result!
        XCTAssertEqual(candidates, ["测试"])
        XCTAssertNil(metadata?["matched_length"])
    }

    func testParseFailureResponse() {
        let json: [Any] = ["FAILED"]
        let result = CloudInputEngine.parseResponse(json)
        XCTAssertNil(result)
    }

    func testParseNilResponse() {
        let result = CloudInputEngine.parseResponse(nil)
        XCTAssertNil(result)
    }

    func testParseInvalidStructure() {
        let json: [Any] = ["SUCCESS", "not an array"]
        let result = CloudInputEngine.parseResponse(json)
        XCTAssertNil(result)
    }

    // MARK: - InputTool

    func testInputToolDisplayNames() {
        XCTAssertEqual(InputTool.Pinyin.displayName, "全拼")
        XCTAssertEqual(InputTool.Wubi.displayName, "五笔 86")
        XCTAssertEqual(InputTool.Shuangpin_Xiaohe.displayName, "小鹤双拼")
    }

    func testInputToolRawValues() {
        XCTAssertEqual(InputTool.Pinyin.rawValue, "zh-t-i0-pinyin")
        XCTAssertEqual(InputTool.Wubi.rawValue, "zh-t-i0-wubi-1986")
    }

    func testInputToolFromRawValue() {
        XCTAssertEqual(InputTool(rawValue: "zh-t-i0-pinyin"), .Pinyin)
        XCTAssertNil(InputTool(rawValue: "invalid"))
    }

    func testAllCasesCount() {
        XCTAssertEqual(InputTool.allCases.count, 8)
    }

    // MARK: - Proxy configuration

    func testHTTPProxyConnectionDictionary() {
        let proxy = ProxyConfiguration(type: .http, host: "127.0.0.1", port: 8080, username: "", password: "")
        let dictionary = proxy.connectionProxyDictionary

        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPPort as String] as? Int, 8080)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSPort as String] as? Int, 8080)
    }

    func testSOCKSProxyConnectionDictionary() {
        let proxy = ProxyConfiguration(type: .socks, host: "localhost", port: 1080, username: "", password: "")
        let dictionary = proxy.connectionProxyDictionary

        XCTAssertEqual(dictionary[kCFNetworkProxiesSOCKSEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary[kCFNetworkProxiesSOCKSProxy as String] as? String, "localhost")
        XCTAssertEqual(dictionary[kCFNetworkProxiesSOCKSPort as String] as? Int, 1080)
    }

    func testProxyConfigurationReturnsNilWhenDisabled() {
        ProxySettings.type = .none
        ProxySettings.host = "127.0.0.1"
        ProxySettings.port = 8080

        XCTAssertNil(ProxySettings.configuration)
    }

    func testProxyConfigurationReturnsPersistedProxy() {
        ProxySettings.type = .http
        ProxySettings.host = "127.0.0.1"
        ProxySettings.port = 8080

        XCTAssertEqual(
            ProxySettings.configuration,
            ProxyConfiguration(type: .http, host: "127.0.0.1", port: 8080, username: "", password: ""))
    }

    func testProxyConfigurationRejectsInvalidHostOrPort() {
        ProxySettings.type = .socks
        ProxySettings.host = "   "
        ProxySettings.port = 0

        XCTAssertNil(ProxySettings.configuration)
    }
    func testTruncatedOrMalformedCloudResponsesAreRejected() {
        let invalidResponses: [Any] = [[], ["SUCCESS"], ["SUCCESS", [[]]],
            ["SUCCESS", [["nihao", ["你好", "你"], [], ["matched_length": [5]]]]],
            ["SUCCESS", [["nihao", ["你好"], [], ["matched_length": [99]]]]],
            ["SUCCESS", [["nihao", ["你好"], [], ["matched_length": [0]]]]]]
        for value in invalidResponses {
            XCTAssertNil(CloudInputEngine.parseResponse(value))
        }
    }

    func testRequestEscapesInputAndUsesSelectedCandidateCount() {
        let request = CloudInputEngine.makeRequest("xi'an&test", scheme: .Pinyin, candidateCount: 20)
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "text" }?.value, "xi'an&test")
        XCTAssertEqual(items.first { $0.name == "num" }?.value, "20")
        XCTAssertEqual(items.first { $0.name == "itc" }?.value, InputTool.Pinyin.rawValue)
    }

    func testPersonalDictionaryIsFullPinyinOnlyAndDeduplicates() throws {
        var options = AccuracyOptions()
        options.customPhrases = "jiekou\t接口\njiekou\t接口测试\n# comment"
        XCTAssertEqual(PersonalDictionary.candidates(for: "jiekou", scheme: .Pinyin, options: options), ["接口", "接口测试"])
        XCTAssertTrue(PersonalDictionary.candidates(for: "jiekou", scheme: .Wubi, options: options).isEmpty)
        let merged = PersonalDictionary.merge(text: "jiekou", cloud: ["借口", "接口"],
            matchedLength: [6, 6], local: ["接口", "接口测试"])
        XCTAssertEqual(merged.0, ["借口", "接口测试", "接口"])
        XCTAssertEqual(merged.1, [6, 6, 6])
        XCTAssertThrowsError(try PersonalDictionary.parse("jiekou"))
        XCTAssertThrowsError(try PersonalDictionary.parse("123\t接口"))
    }

    func testCloudAndCacheUseIdenticalPersonalRanking() {
        let cache = CandidateCache(databasePath: ":memory:")
        defer { cache.close() }
        for _ in 0..<5 { cache.recordSelection(pinyin: "shijie", candidate: "视界") }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CandidateResponseProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let engine = CloudInputEngine(cache: cache, session: session)
        let network = expectation(description: "network candidates")
        let cached = expectation(description: "cached candidates")
        var options = AccuracyOptions()
        options.technicalDictionary = false
        engine.requestCandidates("shijie", scheme: .Pinyin, options: options) { words, lengths, source in
            XCTAssertEqual(source, .network)
            XCTAssertEqual(words, ["视界", "世界"])
            XCTAssertEqual(lengths, [6, 6])
            network.fulfill()
            engine.requestCandidates("shijie", scheme: .Pinyin, options: options) { again, againLengths, source in
                XCTAssertEqual(source, .cache)
                XCTAssertEqual(again, words)
                XCTAssertEqual(againLengths, lengths)
                cached.fulfill()
            }
        }
        wait(for: [network, cached], timeout: 5)
    }

    func testOfflineStillOffersLocalTechnicalWords() {
        let cache = CandidateCache(databasePath: ":memory:")
        defer { cache.close() }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineCandidateProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let engine = CloudInputEngine(cache: cache, session: session)
        let result = expectation(description: "offline dictionary")
        engine.requestCandidates("jiekou", scheme: .Pinyin, options: AccuracyOptions()) { words, lengths, source in
            XCTAssertEqual(words, ["接口"])
            XCTAssertEqual(lengths, [6])
            XCTAssertEqual(source, .cache)
            result.fulfill()
        }
        wait(for: [result], timeout: 5)
    }
}

private final class CandidateResponseProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let data = try! JSONSerialization.data(withJSONObject: ["SUCCESS", [["shijie", ["世界", "视界"], [], ["matched_length": [6, 6]]]]])
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class OfflineCandidateProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
