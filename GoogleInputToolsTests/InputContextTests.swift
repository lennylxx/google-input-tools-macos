import XCTest
@testable import GoogleInputTools

class InputContextTests: XCTestCase {

    var context: InputContext!

    override func setUp() {
        super.setUp()
        context = InputContext(pageSize: 9)
    }

    // MARK: - Initial state

    func testInitialState() {
        XCTAssertEqual(context.composeString, "")
        XCTAssertEqual(context.currentIndex, 0)
        XCTAssertEqual(context.currentPage, 0)
        XCTAssertFalse(context.isEnglishMode)
        XCTAssertTrue(context.candidates.isEmpty)
    }

    // MARK: - Candidates setter

    func testSettingCandidatesResetsPaging() {
        context.currentPage = 2
        context.candidates = ["你好", "你", "拟"]
        XCTAssertEqual(context.currentPage, 0)
    }

    func testSettingCandidatesBuildsNumberedList() {
        context.candidates = ["你好", "你", "拟"]
        XCTAssertEqual(context.numberedCandidates, ["1. 你好", "2. 你", "3. 拟"])
    }

    // MARK: - Paging

    func testTotalPagesEmpty() {
        XCTAssertEqual(context.totalPages, 0)
    }

    func testTotalPagesSinglePage() {
        context.candidates = Array(repeating: "候选", count: 5)
        XCTAssertEqual(context.totalPages, 1)
    }

    func testTotalPagesExactFit() {
        context.candidates = Array(repeating: "候选", count: 9)
        XCTAssertEqual(context.totalPages, 1)
    }

    func testTotalPagesMultiplePages() {
        context.candidates = Array(repeating: "候选", count: 11)
        XCTAssertEqual(context.totalPages, 2)
    }

    func testCurrentPageCandidatesFirstPage() {
        context.candidates = (1...11).map { "候选\($0)" }
        context.currentPage = 0
        XCTAssertEqual(context.currentPageCandidates.count, 9)
        XCTAssertEqual(context.currentPageCandidates.first, "候选1")
        XCTAssertEqual(context.currentPageCandidates.last, "候选9")
    }

    func testCurrentPageCandidatesLastPage() {
        context.candidates = (1...11).map { "候选\($0)" }
        context.currentPage = 1
        XCTAssertEqual(context.currentPageCandidates.count, 2)
        XCTAssertEqual(context.currentPageCandidates.first, "候选10")
        XCTAssertEqual(context.currentPageCandidates.last, "候选11")
    }

    func testCurrentPageCandidatesEmpty() {
        XCTAssertEqual(context.currentPageCandidates, [])
    }

    // MARK: - Index calculations

    func testCurrentPageIndex() {
        context.candidates = (1...20).map { "候选\($0)" }
        context.currentPage = 1
        context.currentIndex = 11
        XCTAssertEqual(context.currentPageIndex, 2) // 11 - 9 = 2
    }

    func testAbsoluteIndex() {
        context.candidates = (1...20).map { "候选\($0)" }
        context.currentPage = 1
        XCTAssertEqual(context.absoluteIndex(forPageIndex: 0), 9)
        XCTAssertEqual(context.absoluteIndex(forPageIndex: 3), 12)
    }

    // MARK: - Numbered page candidates

    func testNumberedPageCandidates() {
        context.candidates = (1...11).map { "候选\($0)" }
        context.currentPage = 1
        XCTAssertEqual(context.numberedPageCandidates, ["1. 候选10", "2. 候选11"])
    }

    func testCurrentNumberedPageCandidate() {
        context.candidates = ["你好", "你", "拟"]
        context.currentIndex = 1
        XCTAssertEqual(context.currentNumberedPageCandidate, "2. 你")
    }

    func testCurrentNumberedPageCandidateOutOfRange() {
        context.candidates = ["你好"]
        context.currentIndex = 5
        XCTAssertEqual(context.currentNumberedPageCandidate, "")
    }

    // MARK: - Current numbered candidate

    func testCurrentNumberedCandidate() {
        context.candidates = ["你好", "你", "拟"]
        context.currentIndex = 2
        XCTAssertEqual(context.currentNumberedCandidate, "3. 拟")
    }

    func testCurrentNumberedCandidateOutOfRange() {
        context.candidates = ["你好"]
        context.currentIndex = 5
        XCTAssertEqual(context.currentNumberedCandidate, "")
    }

    // MARK: - Clean

    func testClean() {
        context.composeString = "nihao"
        context.candidates = ["你好"]
        context.currentIndex = 1
        context.currentPage = 2
        context.visiblePageStart = 5
        context.matchedLength = [3]
        context.isEnglishMode = true

        context.clean()

        XCTAssertEqual(context.composeString, "")
        XCTAssertEqual(context.currentIndex, 0)
        XCTAssertEqual(context.currentPage, 0)
        XCTAssertEqual(context.visiblePageStart, 0)
        XCTAssertTrue(context.candidates.isEmpty)
        XCTAssertTrue(context.matchedLength?.isEmpty ?? true)
        // isEnglishMode is NOT reset by clean()
        XCTAssertTrue(context.isEnglishMode)
    }
}
