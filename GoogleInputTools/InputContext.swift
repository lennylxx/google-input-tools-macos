//
//  InputContext.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

class InputContext {

    static let shared: InputContext = {
        let instance = InputContext()
        return instance
    }()

    private var _composeString: String = ""
    private var _candidates: [String] = []
    private var _numberedCandidates: [String] = []

    func appendComposeString(string: String) -> String {
        _composeString.append(string)
        return _composeString
    }

    func deleteLastChar() -> String {
        _composeString.removeLast()
        return _composeString
    }

    func cleanComposeString() {
        _composeString = ""
    }

    func composeString() -> String {
        return _composeString
    }

    func setCandidates(candidates: [String]) {
        _candidates = candidates
        _numberedCandidates = []
        for i in 0..<_candidates.count {
            _numberedCandidates.append("\(i+1). \(_candidates[i])")
        }
    }

    func candidates() -> [String] {
        return _candidates
    }

    func firstCandidate() -> String {
        return _candidates[0]
    }

    func candidate(index: Int) -> String {
        return _candidates[index]
    }

    func numberedCandidates() -> [String] {
        return _numberedCandidates
    }

    func clean() {
        _composeString = ""
        _candidates = []
    }
}
