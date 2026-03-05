//
//  InputContext.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

class InputContext {

    static let shared = InputContext()

    var composeString: String = ""
    var matchedLength: [Int]? = []
    var currentIndex: Int = 0
    var currentPage: Int = 0
    let pageSize: Int = 9

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

    var totalPages: Int {
        return _candidates.isEmpty ? 0 : (_candidates.count - 1) / pageSize + 1
    }

    var currentPageCandidates: [String] {
        guard !_candidates.isEmpty else { return [] }
        let start = currentPage * pageSize
        let end = min(start + pageSize, _candidates.count)
        return Array(_candidates[start..<end])
    }

    func absoluteIndex(forPageIndex pageIndex: Int) -> Int {
        return currentPage * pageSize + pageIndex
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
        currentPage = 0
        matchedLength = []
        composeString = ""
        _candidates = []
        _numberedCandidates = []
    }
}
