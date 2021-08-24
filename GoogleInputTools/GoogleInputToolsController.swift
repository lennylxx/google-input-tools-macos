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

    func getAndRenderCandidates(compString: String) {

        DispatchQueue.global().async {

            let returnedCandidates = self._cloudInputEngine.requestCandidatesSync(text: compString)

            DispatchQueue.main.async {
                NSLog("main thread candidates: %@", returnedCandidates)

                // update candidates window
                InputContext.shared.setCandidates(candidates: returnedCandidates)
                GoogleInputToolsController.candidatesWindow.update(sender: self.client())
            }
        }
    }

    func appendComposeString(string: String, client sender: Any!) {
        let compString = InputContext.shared.appendComposeString(string: string)

        // set text at cursor
        self.client().setMarkedText(
            compString, selectionRange: NSMakeRange(NSNotFound, NSNotFound),
            replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        getAndRenderCandidates(compString: compString)
    }
    
    func removeLastCharFromComposeString(client sender: Any!) {
        let compString = InputContext.shared.deleteLastChar()

        // set text at cursor
        self.client().setMarkedText(
            compString, selectionRange: NSMakeRange(NSNotFound, NSNotFound),
            replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        getAndRenderCandidates(compString: compString)
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString()

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        GoogleInputToolsController.candidatesWindow.update(sender: client())
    }

    func commitCandidate(client sender: Any!, candidate: String) {
        client().insertText(candidate, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        GoogleInputToolsController.candidatesWindow.update(sender: client())
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("%@", event)

        if event.type == NSEvent.EventType.keyDown {

            let inputString = event.characters!
            let key = inputString.first!

            NSLog("keydown: %@", String(key))

            if key.isLetter {
                NSLog("Alphabet key")
                appendComposeString(string: inputString, client: client)
                return true
            }

            if key.isNumber {
                NSLog("number")
                let keyValue = Int(key.hexDigitValue!)
                let count = InputContext.shared.candidates().count

                NSLog("keyvalue: %d", keyValue)
                if keyValue >= 1 && keyValue <= count {
                    let candidate = InputContext.shared.candidate(index: keyValue - 1)
                    commitCandidate(client: sender, candidate: candidate)
                    return true
                }
            }

            if event.keyCode == kVK_Delete && InputContext.shared.composeString().count > 0 {
                NSLog("backspace")
                removeLastCharFromComposeString(client: sender)
                return true
            }
            
            if event.keyCode == kVK_Return && InputContext.shared.composeString().count > 0 {
                NSLog("return")
                commitComposedString(client: sender)
                return true
            }

            if event.keyCode == kVK_Space && InputContext.shared.candidates().count > 0 {
                NSLog("space")
                let first = InputContext.shared.firstCandidate()
                commitCandidate(client: sender, candidate: first)
                return true
            }
        }

        return false
    }
}
