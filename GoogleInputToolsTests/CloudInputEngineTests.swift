import XCTest
@testable import GoogleInputTools

class CloudInputEngineTests: XCTestCase {

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
}
