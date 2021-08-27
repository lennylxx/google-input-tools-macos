//
//  GoogleInputToolsController.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit

class GoogleInputToolsController: IMKInputController {

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        super.init(server: server, delegate: delegate, client: inputClient)

        InputContext.shared.composeString.subscribe { compString in
            // set text at cursor
            let range = NSMakeRange(NSNotFound, NSNotFound)
            self.client().setMarkedText(compString, selectionRange: range, replacementRange: range)

            if compString.count > 0 {
                self.getAndRenderCandidates(compString)
                CandidatesWindow.shared.show()
            } else {
                InputContext.shared.currentIndex = 0
                CandidatesWindow.shared.hide()
            }
        }
    }

    func getAndRenderCandidates(_ compString: String) {

        DispatchQueue.global().async {

            let returnedCandidates = CloudInputEngine.shared.requestCandidatesSync(compString)

            DispatchQueue.main.async {
                NSLog("main thread candidates: %@", returnedCandidates)

                // update candidates window
                InputContext.shared.candidates = returnedCandidates
                CandidatesWindow.shared.update(sender: self.client())
            }
        }
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString.value

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        CandidatesWindow.shared.update(sender: client())
    }

    func commitCandidate(client sender: Any!, candidate: String) {
        client().insertText(candidate, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        CandidatesWindow.shared.update(sender: client())
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("%@", event)

        if event.type == NSEvent.EventType.keyDown {

            let inputString = event.characters!
            let key = inputString.first!

            NSLog("key=%@", String(key))

            if key.isLetter {
                InputContext.shared.composeString.value.append(inputString)
                return true
            }

            if key.isNumber {
                let keyValue = Int(key.hexDigitValue!)
                let count = InputContext.shared.candidates.count

                if keyValue >= 1 && keyValue <= count {
                    let candidate = InputContext.shared.candidates[keyValue - 1]
                    commitCandidate(client: sender, candidate: candidate)
                    return true
                }
            }

            if event.keyCode == kVK_LeftArrow {

                // keep the marked text unchanged
                let compString = InputContext.shared.composeString.value
                let range = NSMakeRange(NSNotFound, NSNotFound)
                self.client().setMarkedText(
                    compString, selectionRange: range, replacementRange: range)

                if InputContext.shared.currentIndex > 0 {
                    InputContext.shared.currentIndex -= 1
                    CandidatesWindow.shared.update(sender: self.client())
                }
            }

            if event.keyCode == kVK_RightArrow {

                // keep the marked text unchanged
                let compString = InputContext.shared.composeString.value
                let range = NSMakeRange(NSNotFound, NSNotFound)
                self.client().setMarkedText(
                    compString, selectionRange: range, replacementRange: range)

                if InputContext.shared.currentIndex < InputContext.shared.candidates.count - 1 {
                    InputContext.shared.currentIndex += 1
                    CandidatesWindow.shared.update(sender: self.client())
                }
            }

            if event.keyCode == kVK_Delete && InputContext.shared.composeString.value.count > 0 {
                InputContext.shared.composeString.value.removeLast()
                return true
            }

            if (event.keyCode == kVK_Shift || event.keyCode == kVK_Return) && InputContext.shared.composeString.value.count > 0 {
                commitComposedString(client: sender)
                return true
            }

            if event.keyCode == kVK_Space && InputContext.shared.candidates.count > 0 {
                let first = InputContext.shared.candidates.first!
                commitCandidate(client: sender, candidate: first)
                return true
            }
        }

        return false
    }
}
