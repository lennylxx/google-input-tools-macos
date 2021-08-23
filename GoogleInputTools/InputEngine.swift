//
//  InputEngine.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

class InputEngine {

    static let shared: InputEngine = {
        let instance = InputEngine()
        return instance
    }()

    var _composeString: String = ""

    func appendComposeString(string: String) -> String {
        _composeString.append(string)
        return _composeString
    }

    func cleanComposeString() {
        _composeString = ""
    }

    func composeString() -> String {
        return _composeString
    }
}
