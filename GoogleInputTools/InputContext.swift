//
//  InputContext.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

class InputContext {

    static let shared = InputContext()

    // MARK: - Common state
    var composeString: String = ""
    var matchedLength: [Int]? = []
    var currentIndex: Int = 0
    var isEnglishMode: Bool = false

    private var _candidates: [String] = []
    private var _numberedCandidates: [String] = []

    var candidates: [String] {
        get { return _candidates }
        set {
            _candidates = newValue
            currentPage = 0
            _numberedCandidates = []
            for i in 0..<_candidates.count {
                _numberedCandidates.append("\(i+1). \(_candidates[i])")
            }
        }
    }

    // MARK: - System UI state
    // Tracks the first visible candidate index inferred from IMKCandidates callbacks
    var visiblePageStart: Int = 0

    // MARK: - Custom UI state
    var currentPage: Int = 0

    var pageSize: Int { UISettings.pageSize }

    var totalPages: Int {
        return _candidates.isEmpty ? 0 : (_candidates.count - 1) / pageSize + 1
    }

    var currentPageCandidates: [String] {
        guard !_candidates.isEmpty else { return [] }
        let start = currentPage * pageSize
        let end = min(start + pageSize, _candidates.count)
        return Array(_candidates[start..<end])
    }

    var currentPageIndex: Int {
        return currentIndex - currentPage * pageSize
    }

    func absoluteIndex(forPageIndex pageIndex: Int) -> Int {
        return currentPage * pageSize + pageIndex
    }

    var numberedPageCandidates: [String] {
        let page = currentPageCandidates
        return page.enumerated().map { "\($0.offset + 1). \($0.element)" }
    }

    var currentNumberedPageCandidate: String {
        let page = numberedPageCandidates
        let idx = currentPageIndex
        if idx >= 0 && idx < page.count {
            return page[idx]
        }
        return ""
    }

    var currentNumberedCandidate: String {
        if currentIndex >= 0 && currentIndex < _numberedCandidates.count {
            return _numberedCandidates[currentIndex]
        } else {
            return ""
        }
    }

    var numberedCandidates: [String] {
        return _numberedCandidates
    }

    func clean() {
        currentIndex = 0
        visiblePageStart = 0
        currentPage = 0
        matchedLength = []
        composeString = ""
        _candidates = []
        _numberedCandidates = []
    }
}
