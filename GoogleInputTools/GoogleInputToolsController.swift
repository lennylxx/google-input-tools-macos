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

    private var uiManager: CandidateUIManager
    private var systemUIManager: SystemUICandidateManager?
    private var server: IMKServer

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        NSLog("\(#function)(\(inputClient))")

        self.server = server

        if UISettings.systemUI {
            let sysManager = SystemUICandidateManager(server: server)
            self.uiManager = sysManager
            self.systemUIManager = sysManager
        } else {
            self.uiManager = CustomUICandidateManager()
            self.systemUIManager = nil
        }

        super.init(server: server, delegate: delegate, client: inputClient)

        Self.retainedControllers.append(self)

        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadUIManager),
            name: NSNotification.Name("PreferencesSaved"), object: nil)
    }

    @objc private func reloadUIManager() {
        NSLog("Reloading UI manager, systemUI=\(UISettings.systemUI)")
        uiManager.reset()

        if UISettings.systemUI {
            let sysManager = SystemUICandidateManager(server: server)
            uiManager = sysManager
            systemUIManager = sysManager
        } else {
            uiManager = CustomUICandidateManager()
            systemUIManager = nil
        }
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
        uiManager.reset()
    }

    func getAndRenderCandidates(_ compString: String) {

        CloudInputEngine.shared.requestCandidates(compString) { candidates, matchedLength in
            DispatchQueue.main.async {
                // Discard stale results if compose string has changed
                guard InputContext.shared.composeString == compString else {
                    NSLog("Discarding stale results for: \(compString)")
                    return
                }

                NSLog("main thread candidates: \(candidates)")

                InputContext.shared.candidates = candidates
                InputContext.shared.matchedLength = matchedLength

                self.uiManager.updateCandidates(client: self.client())
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

        if compString.count > 0 {
            self.getAndRenderCandidates(compString)
            uiManager.show()
        } else {
            uiManager.reset()
        }
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        uiManager.reset()
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
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        NSLog("\(#function)")

        return systemUIManager?.allCandidates() ?? InputContext.shared.candidates
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        NSLog("candidate=\(candidate)")
        systemUIManager?.candidateSelected(candidate)
        commitCandidate(client: self.client())
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        systemUIManager?.candidateSelectionChanged(candidate)
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

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences(_:)),
            keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        return menu
    }

    @objc override func showPreferences(_ sender: Any?) {
        PreferencesWindow.shared.showWindow()
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
                if uiManager.selectByNumber(keyValue: keyValue) {
                    commitCandidate(client: sender)
                    return true
                }
                return false
            }

            else if (event.keyCode == kVK_LeftArrow || event.keyCode == kVK_RightArrow)
                && InputContext.shared.candidates.count > 0
            {
                uiManager.handleArrowKey(event: event, client: self.client())
                return true
            }

            else if (event.keyCode == kVK_ANSI_Equal || event.keyCode == kVK_DownArrow)
                && InputContext.shared.candidates.count > 0
            {
                uiManager.pageDown(sender: sender, client: self.client())
                return true
            }

            else if (event.keyCode == kVK_ANSI_Minus || event.keyCode == kVK_UpArrow)
                && InputContext.shared.candidates.count > 0
            {
                uiManager.pageUp(sender: sender, client: self.client())
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
                uiManager.reset()
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
