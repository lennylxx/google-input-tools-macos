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

        let (candidates, matchedLength) = result!
        XCTAssertEqual(candidates, ["你好", "你号", "尼好"])
        XCTAssertEqual(matchedLength, [5, 5, 5])
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

        let (candidates, matchedLength) = result!
        XCTAssertEqual(candidates.count, 4)
        XCTAssertEqual(matchedLength, [3, 1, 1, 2])
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

        let (candidates, matchedLength) = result!
        XCTAssertEqual(candidates, ["测试"])
        XCTAssertNil(matchedLength)
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
        XCTAssertEqual(InputTool.Pinyin.displayName, "Pinyin")
        XCTAssertEqual(InputTool.Wubi.displayName, "Wubi 86")
        XCTAssertEqual(InputTool.Shuangpin_Xiaohe.displayName, "Shuangpin (Xiaohe)")
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
        let proxy = ProxyConfiguration(type: .http, host: "127.0.0.1", port: 8080)
        let dictionary = proxy.connectionProxyDictionary

        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPPort as String] as? Int, 8080)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSPort as String] as? Int, 8080)
    }

    func testSOCKSProxyConnectionDictionary() {
        let proxy = ProxyConfiguration(type: .socks, host: "localhost", port: 1080)
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
            ProxyConfiguration(type: .http, host: "127.0.0.1", port: 8080))
    }

    func testProxyConfigurationRejectsInvalidHostOrPort() {
        ProxySettings.type = .socks
        ProxySettings.host = "   "
        ProxySettings.port = 0

        XCTAssertNil(ProxySettings.configuration)
    }
}
