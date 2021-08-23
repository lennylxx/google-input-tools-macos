//
//  GoogleInputToolsController.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit

class GoogleInputToolsController: IMKInputController {

    static let candidatesWindow: CandidatesWindow = {
        let instance = CandidatesWindow()
        return instance
    }()

    let _cloudInputEngine = CloudInputEngine()

    func appendComposedString(string: String, client sender: Any!) {
        let compString = InputEngine.shared.appendComposeString(string: string)

        DispatchQueue.global().async {

            let returnedCandidates = self._cloudInputEngine.requestCandidatesSync(text: compString)
            NSLog("returned candidates: %@", returnedCandidates)

            DispatchQueue.main.async {
                NSLog("main thread candidates: %@", returnedCandidates)

                // set text at cursor
                self.client().setMarkedText(
                    compString, selectionRange: NSMakeRange(0, compString.count),
                    replacementRange: NSMakeRange(NSNotFound, NSNotFound))

                // update candidates window
                InputEngine.shared.setCandidates(candidates: returnedCandidates)
                GoogleInputToolsController.candidatesWindow.update(sender: self.client())
            }
        }
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputEngine.shared.composeString()

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputEngine.shared.clean()
        GoogleInputToolsController.candidatesWindow.update(sender: client())
    }

    func commitCandidate(client sender: Any!, candidate: String) {
        client().insertText(candidate, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputEngine.shared.clean()
        GoogleInputToolsController.candidatesWindow.update(sender: client())
    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        NSLog("inputText: %@", string)

        return false
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("%@", event)

        if event.type == NSEvent.EventType.keyDown {

            let inputString = event.characters!
            let key = inputString.first!

            NSLog("keydown: %@", String(key))

            if key.isLetter {
                NSLog("Alphabet key")
                appendComposedString(string: inputString, client: client)
                return true
            }

            if key.isNumber {
                NSLog("number")
                let keyValue = Int(key.hexDigitValue!)
                let count = InputEngine.shared.candidates().count

                NSLog("keyvalue: %d", keyValue)
                if keyValue >= 1 && keyValue <= count {
                    let candidate = InputEngine.shared.candidate(index: keyValue - 1)
                    commitCandidate(client: sender, candidate: candidate)
                    return true
                }
            }

            if event.keyCode == kVK_Return && InputEngine.shared.composeString().count > 0 {
                NSLog("return")
                commitComposedString(client: sender)
                return true
            }

            if event.keyCode == kVK_Space && InputEngine.shared.candidates().count > 0 {
                NSLog("space")
                let first = InputEngine.shared.firstCandidate()
                commitCandidate(client: sender, candidate: first)
                return true
            }
        }

        return false
    }
}
