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

    func isAlphanumeric(key: Character) -> Bool {
        if key >= "a" && key <= "z" || key >= "0" && key <= "9" {
            return true
        } else {
            return false
        }
    }

    func appendComposedString(string: String, client sender: Any!) {
        let compString = InputEngine.shared.appendComposeString(string: string)

        self._cloudInputEngine.requestCandidates(text: compString) { candidates in
            NSLog("returned candidates: %@", candidates)
        }

        // set text at cursor
        client().setMarkedText(
            compString, selectionRange: NSMakeRange(0, compString.count),
            replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        // update candidates window
        GoogleInputToolsController.candidatesWindow.update(sender: client())
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputEngine.shared.composeString()

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputEngine.shared.cleanComposeString()
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

            if isAlphanumeric(key: key) {
                NSLog("Alphanumeric key")
                appendComposedString(string: inputString, client: client)
                return true
            }

            if (event.keyCode == kVK_Space || event.keyCode == kVK_Return)
                && InputEngine.shared.composeString().count > 0
            {
                NSLog("space or return")
                commitComposedString(client: sender)
                return true
            }
        }

        return false
    }
}
