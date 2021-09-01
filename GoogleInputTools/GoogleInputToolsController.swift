//
//  GoogleInputToolsController.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit

class GoogleInputToolsController: IMKInputController {

    private let candidates: IMKCandidates

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        self.candidates = IMKCandidates(
            server: server, panelType: kIMKSingleRowSteppingCandidatePanel)

        super.init(server: server, delegate: delegate, client: inputClient)

        InputContext.shared.composeString.subscribe { compString in
            // set text at cursor
            let range = NSMakeRange(NSNotFound, NSNotFound)
            self.client().setMarkedText(compString, selectionRange: range, replacementRange: range)

            if UISettings.SystemUI {
                if compString.count > 0 {
                    self.candidates.update()
                    self.candidates.show()
                } else {
                    self.candidates.hide()
                }
            } else {
                if compString.count > 0 {
                    self.getAndRenderCandidates(compString)
                    CandidatesWindow.shared.show()
                } else {
                    InputContext.shared.currentIndex = 0
                    CandidatesWindow.shared.hide()
                }
            }
        }
    }

    override func activateServer(_ sender: Any!) {
        NSLog("%@", "\(#function)((\(sender))")
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any) {
        NSLog("%@", "\(#function)((\(sender))")

        self.candidates.hide()
        InputContext.shared.clean()

        super.deactivateServer(sender)
    }

    func getAndRenderCandidates(_ compString: String) {

        DispatchQueue.global().async {

            let (candidates, matchedLength) = CloudInputEngine.shared.requestCandidatesSync(
                compString)

            DispatchQueue.main.async {
                NSLog("main thread candidates: %@", candidates)

                InputContext.shared.candidates = candidates
                InputContext.shared.matchedLength = matchedLength

                // update custom candidates window
                if !UISettings.SystemUI {
                    CandidatesWindow.shared.update(sender: self.client())
                }
            }
        }
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString.value

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    func commitCandidate(client sender: Any!) {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString.value
        let index = InputContext.shared.currentIndex
        let candidate = InputContext.shared.candidates[index]
        let matched = InputContext.shared.matchedLength?[index] ?? compString.count

        let fromIndex = compString.index(
            compString.endIndex, offsetBy: matched - compString.count)
        let remain = compString[fromIndex...]

        client().insertText(candidate, replacementRange: NSMakeRange(0, matched))
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client().setMarkedText(remain, selectionRange: range, replacementRange: range)

        InputContext.shared.clean()
        InputContext.shared.composeString.value = String(remain)

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString.value
        let (candidates, matchedLength) = CloudInputEngine.shared.requestCandidatesSync(compString)

        NSLog("candidates: %@", candidates)

        InputContext.shared.candidates = candidates
        InputContext.shared.matchedLength = matchedLength
        return candidates
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        let id = InputContext.shared.candidates.firstIndex(of: candidate) ?? 0

        NSLog("candidate index: \(id)")
        InputContext.shared.currentIndex = id
        commitCandidate(client: self.client())
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")
    }

    override func commitComposition(_ sender: Any!) {
        NSLog("\(#function)")
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
                    InputContext.shared.currentIndex = keyValue - 1
                    commitCandidate(client: sender)
                    return true
                }

                return false
            }

            if event.keyCode == kVK_LeftArrow || event.keyCode == kVK_RightArrow {

                if event.keyCode == kVK_LeftArrow && InputContext.shared.currentIndex > 0 {
                    InputContext.shared.currentIndex -= 1
                }

                if event.keyCode == kVK_RightArrow
                    && InputContext.shared.currentIndex < InputContext.shared.candidates.count
                        - 1
                {
                    InputContext.shared.currentIndex += 1
                }

                if UISettings.SystemUI {
                    self.candidates.interpretKeyEvents([event])
                } else {
                    // keep the marked text unchanged
                    let compString = InputContext.shared.composeString.value
                    let range = NSMakeRange(NSNotFound, NSNotFound)
                    self.client().setMarkedText(
                        compString, selectionRange: range, replacementRange: range)
                    CandidatesWindow.shared.update(sender: self.client())
                }

                return true
            }

            if event.keyCode == kVK_Delete && InputContext.shared.composeString.value.count > 0 {
                InputContext.shared.composeString.value.removeLast()
                return true
            }

            if (event.keyCode == kVK_Shift || event.keyCode == kVK_Return)
                && InputContext.shared.composeString.value.count > 0
            {
                commitComposedString(client: sender)
                return true
            }

            if event.keyCode == kVK_Space && InputContext.shared.candidates.count > 0 {
                commitCandidate(client: sender)
                return true
            }
        }

        return false
    }
}
