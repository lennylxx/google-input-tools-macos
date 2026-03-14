//
//  PunctuationMapTests.swift
//  GoogleInputToolsTests
//

import XCTest

@testable import GoogleInputTools

class PunctuationMapTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InputContext.shared.nextSingleQuoteIsOpen = true
        InputContext.shared.nextDoubleQuoteIsOpen = true
    }

    func testBasicPunctuation() {
        XCTAssertEqual(PunctuationMap.fullWidth(for: ","), "，")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "."), "。")
        XCTAssertEqual(PunctuationMap.fullWidth(for: ";"), "；")
        XCTAssertEqual(PunctuationMap.fullWidth(for: ":"), "：")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "?"), "？")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "!"), "！")
    }

    func testBrackets() {
        XCTAssertEqual(PunctuationMap.fullWidth(for: "("), "（")
        XCTAssertEqual(PunctuationMap.fullWidth(for: ")"), "）")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "<"), "《")
        XCTAssertEqual(PunctuationMap.fullWidth(for: ">"), "》")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "["), "【")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "]"), "】")
    }

    func testSpecialCharacters() {
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\\"), "、")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "^"), "……")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "_"), "——")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "~"), "～")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "$"), "￥")
        XCTAssertEqual(PunctuationMap.fullWidth(for: "`"), "·")
    }

    func testUnmappedCharacters() {
        XCTAssertNil(PunctuationMap.fullWidth(for: "-"))
        XCTAssertNil(PunctuationMap.fullWidth(for: "="))
        XCTAssertNil(PunctuationMap.fullWidth(for: "+"))
        XCTAssertNil(PunctuationMap.fullWidth(for: "/"))
        XCTAssertNil(PunctuationMap.fullWidth(for: "a"))
        XCTAssertNil(PunctuationMap.fullWidth(for: "1"))
    }

    func testSingleQuoteAlternation() {
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2018}")  // '
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2019}")  // '
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2018}")  // '
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2019}")  // '
    }

    func testDoubleQuoteAlternation() {
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201C}")  // "
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201D}")  // "
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201C}")  // "
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201D}")  // "
    }

    func testQuoteStateIndependence() {
        // Single and double quotes track state independently
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2018}")  // open '
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201C}")  // open "
        XCTAssertEqual(PunctuationMap.fullWidth(for: "'"), "\u{2019}")  // close '
        XCTAssertEqual(PunctuationMap.fullWidth(for: "\""), "\u{201D}")  // close "
    }
}
