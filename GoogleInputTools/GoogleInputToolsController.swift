//
//  GoogleInputToolsController.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit

class GoogleInputToolsController: IMKInputController {

    // Prevent ARC from deallocating controllers while InputMethodKit still holds unretained references
    private static var retainedControllers = [GoogleInputToolsController]()

    private let candidates: IMKCandidates

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        NSLog("\(#function)(\(inputClient))")

        self.candidates = IMKCandidates(
            server: server, panelType: kIMKSingleRowSteppingCandidatePanel)

        super.init(server: server, delegate: delegate, client: inputClient)

        Self.retainedControllers.append(self)
    }

    override func client() -> (IMKTextInput & NSObjectProtocol)! {
        let c = super.client()
        NSLog("client=\(c)")
        return c
    }

    override func activateServer(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
    }

    override func deactivateServer(_ sender: Any) {
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        InputContext.shared.clean()
        self.candidates.update()
        self.candidates.hide()
    }

    func getAndRenderCandidates(_ compString: String) {

        DispatchQueue.global().async {

            let (candidates, matchedLength) = CloudInputEngine.shared.requestCandidatesSync(
                compString)

            DispatchQueue.main.async {
                NSLog("main thread candidates: \(candidates)")

                InputContext.shared.candidates = candidates
                InputContext.shared.matchedLength = matchedLength

                // update candidates window
                if UISettings.SystemUI {
                    self.candidates.update()
                } else {
                    CandidatesWindow.shared.update(sender: self.client())
                }
            }
        }
    }

    func updateCandidatesWindow() {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString
        NSLog("compString=\(compString)")

        // set text at cursor
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client().setMarkedText(compString, selectionRange: range, replacementRange: range)

        if UISettings.SystemUI {
            if compString.count > 0 {
                self.getAndRenderCandidates(compString)
                self.candidates.show(kIMKLocateCandidatesBelowHint)
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

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        self.candidates.update()
        self.candidates.hide()

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    func commitCandidate(client sender: Any!) {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString
        let index = InputContext.shared.currentIndex
        let candidate = InputContext.shared.candidates[index]
        let matched = InputContext.shared.matchedLength?[index] ?? compString.count

        NSLog("compString=\(compString), length=\(compString.count)")
        NSLog("currentIndex=\(index), currentCandidate=\(candidate), matchedLength=\(matched)")

        let fromIndex = compString.index(
            compString.endIndex, offsetBy: matched - compString.count)
        let remain = compString[fromIndex...]

        NSLog("fromIndex=\(fromIndex.utf16Offset(in: compString)), remain=\(remain)")

        client().insertText(candidate, replacementRange: NSMakeRange(0, matched))
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client().setMarkedText(remain, selectionRange: range, replacementRange: range)

        InputContext.shared.clean()
        InputContext.shared.composeString = String(remain)
        updateCandidatesWindow()

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        NSLog("\(#function)")

        return InputContext.shared.currentPageCandidates
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        let id = InputContext.shared.candidates.firstIndex(of: candidate) ?? 0

        NSLog("candidate=\(candidate), index=\(id)")
        InputContext.shared.currentIndex = id
        commitCandidate(client: self.client())
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        let id = InputContext.shared.candidates.firstIndex(of: candidate) ?? 0

        NSLog("candidate=\(candidate), index=\(id)")
        InputContext.shared.currentIndex = id
    }

    override func commitComposition(_ sender: Any!) {
        NSLog("\(#function)")
    }

    override func updateComposition() {
        NSLog("\(#function)")
    }

    override func cancelComposition() {
        NSLog("\(#function)")
    }

    override func selectionRange() -> NSRange {
        NSLog("\(#function)")

        return NSMakeRange(NSNotFound, NSNotFound)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        return Int(events.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        NSLog("%@", event)

        // Bare Shift key toggles Chinese/English mode (on key release)
        if event.type == NSEvent.EventType.flagsChanged {
            if (event.keyCode == kVK_Shift || event.keyCode == kVK_RightShift)
                && !event.modifierFlags.contains(.shift)
            {
                let context = InputContext.shared
                context.isEnglishMode = !context.isEnglishMode
                NSLog("Shift toggled, isEnglishMode=\(context.isEnglishMode)")

                if context.isEnglishMode && context.composeString.count > 0 {
                    commitComposedString(client: sender)
                }
                return true
            }
        }

        // In English mode, pass all keys through
        if InputContext.shared.isEnglishMode {
            return false
        }

        if event.type == NSEvent.EventType.keyDown {

            let inputString = event.characters!
            let key = inputString.first!

            NSLog("key=\(Utilities.TranslateKey(event)), keyCode=\(event.keyCode)")

            if key.isLetter {
                InputContext.shared.composeString.append(inputString)
                updateCandidatesWindow()
                return true
            }

            else if key.isNumber {
                let keyValue = Int(key.hexDigitValue!)
                let context = InputContext.shared
                let pageCandidates = context.currentPageCandidates

                NSLog("keyValue=\(keyValue), page=\(context.currentPage), pageCount=\(pageCandidates.count)")

                if keyValue >= 1 && keyValue <= pageCandidates.count {
                    context.currentIndex = context.absoluteIndex(forPageIndex: keyValue - 1)
                    commitCandidate(client: sender)
                    return true
                }

                return false
            }

            else if event.keyCode == kVK_LeftArrow || event.keyCode == kVK_RightArrow {

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
                    let compString = InputContext.shared.composeString
                    let range = NSMakeRange(NSNotFound, NSNotFound)
                    self.client().setMarkedText(
                        compString, selectionRange: range, replacementRange: range)
                    CandidatesWindow.shared.update(sender: self.client())
                }

                return true
            }

            else if (event.keyCode == kVK_ANSI_Equal || event.keyCode == kVK_DownArrow)
                && InputContext.shared.candidates.count > 0
            {
                let context = InputContext.shared
                if context.currentPage < context.totalPages - 1 {
                    context.currentPage += 1
                    self.candidates.update()
                }
                return true
            }

            else if (event.keyCode == kVK_ANSI_Minus || event.keyCode == kVK_UpArrow)
                && InputContext.shared.candidates.count > 0
            {
                let context = InputContext.shared
                if context.currentPage > 0 {
                    context.currentPage -= 1
                    self.candidates.update()
                }
                return true
            }

            else if event.keyCode == kVK_Delete && InputContext.shared.composeString.count > 0 {
                InputContext.shared.composeString.removeLast()
                updateCandidatesWindow()
                return true
            }

            else if event.keyCode == kVK_Return
                && InputContext.shared.composeString.count > 0
            {
                commitComposedString(client: sender)
                return true
            }

            else if event.keyCode == kVK_Space && InputContext.shared.candidates.count > 0 {
                commitCandidate(client: sender)
                return true
            }

            else if event.keyCode == kVK_Escape {
                InputContext.shared.clean()
                let range = NSMakeRange(NSNotFound, NSNotFound)
                client().setMarkedText("", selectionRange: range, replacementRange: range)
                self.candidates.update()
                self.candidates.hide()
                return true
            }

            else {
                commitComposedString(client: sender)
                return false
            }
        }

        return false
    }

    func simulateControlSpace() {
        let controlDownEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],  // Pressing Control key
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 59  // Key code for Control key
        )

        let spaceDownEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],  // Control is still held down
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49  // Key code for Space key
        )

        // release the Space key
        let spaceUpEvent = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [.control],  // Control is still held down
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49  // Key code for Space key
        )

        // release the Control key
        let controlUpEvent = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 59  // Key code for Control key
        )

        // Post the events to simulate pressing Control + Space

        //NSEvent.post(controlDownEvent)
        //NSEvent.post(spaceDownEvent)
        //NSEvent.post(spaceUpEvent)
        //NSEvent.post(controlUpEvent)
    }

}
