//
//  InputContext.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation

enum CandidateSource {
    case cache
    case network

    var indicator: String? {
        switch self {
        case .cache: return nil
        case .network: return "☁️"
        }
    }
}

class InputContext {

    static let shared = InputContext()

    // MARK: - Common state
    var composeString: String = "" {
        didSet { invalidateCandidates() }
    }
    private(set) var revision: UInt64 = 0
    private(set) var isRequestPending = false
    var pendingSpace = false
    var continuesEnglishOnSpace = false
    private(set) var englishCandidateIndices = Set<Int>()
    private(set) var candidateLearningInputs = [String?]()
    var currentCandidateIsEnglish: Bool { englishCandidateIndices.contains(currentIndex) }
    var matchedLength: [Int]? = []
    var currentIndex: Int = 0
    var isEnglishMode: Bool = false
    var nextSingleQuoteIsOpen: Bool = true
    var nextDoubleQuoteIsOpen: Bool = true
    var candidateSource: CandidateSource = .cache

    private var _candidates: [String] = []
    private var _numberedCandidates: [String] = []

    var candidates: [String] {
        get {
            assert(Thread.isMainThread, "InputContext.candidates must be accessed on main thread")
            return _candidates
        }
        set {
            assert(Thread.isMainThread, "InputContext.candidates must be set on main thread")
            _candidates = newValue
            englishCandidateIndices = []
            candidateLearningInputs = []
            currentIndex = 0
            visiblePageStart = 0
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

    var pageSize: Int

    init(pageSize: Int? = nil) {
        self.pageSize = pageSize ?? UISettings.pageSize
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

    var pageIndicator: String {
        guard totalPages > 1 else { return "" }
        let up = currentPage > 0 ? "▲" : "△"
        let down = currentPage < totalPages - 1 ? "▼" : "▽"
        return " \(up) \(down)"
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
        candidateSource = .cache
        _candidates = []
        _numberedCandidates = []
    }

    func invalidateCandidates() {
        revision &+= 1
        isRequestPending = !composeString.isEmpty
        _candidates = []
        _numberedCandidates = []
        matchedLength = []
        currentIndex = 0
        currentPage = 0
        visiblePageStart = 0
        pendingSpace = false
        continuesEnglishOnSpace = false
        englishCandidateIndices = []
        candidateLearningInputs = []
    }

    @discardableResult
    func acceptCandidates(_ values: [String], matchedLength: [Int]?,
                          source: CandidateSource, revision expected: UInt64) -> Bool {
        guard revision == expected, !composeString.isEmpty else { return false }
        isRequestPending = false
        candidates = values
        self.matchedLength = values.indices.map { index in
            if let lengths = matchedLength, index < lengths.count,
               lengths[index] > 0, lengths[index] <= composeString.count {
                return lengths[index]
            }
            return composeString.count
        }
        candidateSource = source
        return true
    }

    @discardableResult
    func acceptSuggestions(_ suggestions: [InputSuggestion], source: CandidateSource, revision: UInt64) -> Bool {
        guard acceptCandidates(suggestions.map(\.text), matchedLength: suggestions.map(\.consumed),
                               source: source, revision: revision) else { return false }
        englishCandidateIndices = Set(suggestions.indices.filter { suggestions[$0].isEnglish })
        candidateLearningInputs = suggestions.map(\.learningInput)
        return true
    }
}
