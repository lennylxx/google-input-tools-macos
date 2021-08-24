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

    var composeString: String {
        get { return _composeString }
        set { _composeString = newValue }
    }

    var candidates: [String] {
        get { return _candidates }
        set {
            _candidates = newValue
            _numberedCandidates = []
            for i in 0..<_candidates.count {
                _numberedCandidates.append("\(i+1). \(_candidates[i])")
            }
        }
    }

    var numberedCandidates: [String] {
        return _numberedCandidates
    }

    func clean() {
        _composeString = ""
        _candidates = []
        _numberedCandidates = []
    }
}
