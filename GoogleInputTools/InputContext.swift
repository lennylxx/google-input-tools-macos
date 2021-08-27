//
//  InputContext.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

class InputContext {

    static let shared = InputContext()

    var composeString: Observable<String> = Observable("")
    private var _candidates: Observable<[String]> = Observable<[String]>([])
    private var _numberedCandidates: [String] = []

    var currentIndex: Int = 0

    var candidates: [String] {
        get { return _candidates.value }
        set {
            _candidates.value = newValue
            _numberedCandidates = []
            for i in 0..<_candidates.value.count {
                _numberedCandidates.append("\(i+1). \(_candidates.value[i])")
            }
        }
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
        composeString.value = ""
        _candidates.value = []
        _numberedCandidates = []
    }
}
