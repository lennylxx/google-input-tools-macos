//
//  GoogleInputToolsController.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit

// The host must lay out the actual pinyin, including line wrapping. AppKit ranges
// are UTF-16 offsets; the selection is relative to the marked string.
struct CompositionText {
    let string: String
    var selectionRange: NSRange { NSRange(location: string.utf16.count, length: 0) }
    let replacementRange = NSRange(location: NSNotFound, length: 0)

    func apply(to client: IMKTextInput) {
        client.setMarkedText(string, selectionRange: selectionRange,
                             replacementRange: replacementRange)
    }
}

class GoogleInputToolsController: IMKInputController {

    // Prevent ARC from deallocating controllers while InputMethodKit still holds unretained references
    private static var retainedControllers = [GoogleInputToolsController]()

    private var uiManager: CandidateUIManager
    private var systemUIManager: SystemUICandidateManager?
    private var server: IMKServer
    private var shiftTracker = ShiftToggleTracker()
    var inputEngine = MixedInputEngine.shared
    var learningCache = CandidateCache.shared

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
        InputContext.shared.pageSize = UISettings.pageSize
        InputContext.shared.invalidateCandidates()
        if InputContext.shared.isEnglishMode {
            commitComposedString(client: client())
            return
        }
        if !InputContext.shared.composeString.isEmpty { updateCandidatesWindow() }
    }

    override func client() -> (IMKTextInput & NSObjectProtocol)! {
        let c = super.client()
        NSLog("client=\(c)")
        return c
    }

    override func activateServer(_ sender: Any!) {
        shiftTracker.cancel()
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
    }

    override func deactivateServer(_ sender: Any) {
        shiftTracker.cancel()
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        InputContext.shared.clean()
        uiManager.reset()
    }

    func getAndRenderCandidates(_ compString: String) {
        let revision = InputContext.shared.revision
        let scheme = UISettings.inputTool
        let englishMode = InputContext.shared.isEnglishMode
        let continuesEnglish = inputEngine.request(compString, scheme: scheme,
            options: UISettings.accuracyOptions, englishEnabled: UISettings.englishCompletion,
            typoEnabled: UISettings.pinyinTypoCorrection) { result in
            DispatchQueue.main.async {
                let context = InputContext.shared
                guard UISettings.inputTool == scheme, context.isEnglishMode == englishMode,
                    context.acceptSuggestions(result.suggestions, source: result.source, revision: revision) else {
                    return
                }
                if context.pendingSpace && !result.suggestions.isEmpty {
                    context.pendingSpace = false
                    self.commitCandidate(client: self.client())
                    return
                }
                if result.suggestions.isEmpty && context.continuesEnglishOnSpace {
                    self.uiManager.hide()
                    return
                }
                self.uiManager.updateCandidates(client: self.client())
                self.uiManager.show()
            }
        }
        InputContext.shared.continuesEnglishOnSpace = continuesEnglish
    }

    func updateCandidatesWindow() {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString
        NSLog("compString=\(compString)")

        if compString.count > 0 {
            CompositionText(string: compString).apply(to: client())
            // Preserve the last rendered candidates while the new request is in
            // flight. Only the custom window needs to follow the updated caret.
            if !UISettings.systemUI {
                self.uiManager.updateCandidates(client: self.client())
                self.uiManager.show()
            }
            self.getAndRenderCandidates(compString)
        } else {
            CompositionText(string: "").apply(to: client())
            uiManager.reset()
        }
    }

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString
        guard !compString.isEmpty else { return }
        let range = NSMakeRange(NSNotFound, 0)
        // insertText replaces the marked range in one edit, avoiding a temporary
        // empty line and caret jump at the wrapping boundary.
        client().insertText(compString, replacementRange: range)

        InputContext.shared.clean()
        uiManager.reset()
    }

    func commitCandidate(client sender: Any!) {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString
        let index = InputContext.shared.currentIndex
        let candidates = InputContext.shared.candidates
        guard index >= 0 && index < candidates.count else {
            NSLog("commitCandidate: index \(index) out of bounds (count=\(candidates.count))")
            return
        }
        let candidate = candidates[index]
        let lengths = InputContext.shared.matchedLength ?? []
        let matched = index < lengths.count ? lengths[index] : compString.count
        let clampedMatched = min(matched, compString.count)

        NSLog("compString=\(compString), length=\(compString.count)")
        NSLog(
            "currentIndex=\(index), currentCandidate=\(candidate), matchedLength=\(clampedMatched)")

        // Record user selection for frequency-based re-ranking
        let context = InputContext.shared
        if !context.currentCandidateIsEnglish {
            let pinyin = index < context.candidateLearningInputs.count
                ? context.candidateLearningInputs[index] ?? String(compString.prefix(clampedMatched))
                : String(compString.prefix(clampedMatched))
            let prefix = MixedInputQuery(compString).prefix
            let learnedCandidate = candidate.hasPrefix(prefix) ? String(candidate.dropFirst(prefix.count)) : candidate
            learningCache.recordSelection(pinyin: pinyin, candidate: learnedCandidate,
                scheme: UISettings.inputTool, explicit: index > 0,
                options: UISettings.accuracyOptions)
        }

        let fromIndex = compString.index(
            compString.endIndex, offsetBy: clampedMatched - compString.count)
        let remain = compString[fromIndex...]

        NSLog("fromIndex=\(fromIndex.utf16Offset(in: compString)), remain=\(remain)")

        let range = NSMakeRange(NSNotFound, 0)
        client().insertText(candidate, replacementRange: range)

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
        guard !InputContext.shared.composeString.isEmpty else { return }
        commitComposedString(client: sender)
    }

    override func updateComposition() {
        NSLog("\(#function)")
    }

    override func cancelComposition() {
        guard !InputContext.shared.composeString.isEmpty else { return }
        commitComposedString(client: client())
    }

    override func selectionRange() -> NSRange {
        NSLog("\(#function)")

        return NSMakeRange(NSNotFound, NSNotFound)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        let events: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        return Int(events.rawValue)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        for (index, title) in ["中英混输", "纯英文"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectInputMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = InputContext.shared.isEnglishMode == (index == 1) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let prefsItem = NSMenuItem(
            title: "设置…",
            action: #selector(showPreferences(_:)),
            keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        return menu
    }

    @objc override func showPreferences(_ sender: Any?) {
        PreferencesWindow.shared.showWindow()
    }

    private func toggleEnglishMode(client sender: Any!) {
        setEnglishMode(!InputContext.shared.isEnglishMode, client: sender)
    }

    @objc private func selectInputMode(_ sender: NSMenuItem) {
        setEnglishMode(sender.tag == 1, client: client())
    }

    private func setEnglishMode(_ enabled: Bool, client sender: Any!) {
        let context = InputContext.shared
        if !context.composeString.isEmpty { commitComposedString(client: sender) }
        shiftTracker.cancel()
        context.isEnglishMode = enabled
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }
        // Return before any composition, candidate, or punctuation handling.
        if Utilities.isApplicationShortcut(event.modifierFlags) {
            shiftTracker.cancel()
            InputContext.shared.pendingSpace = false
            return false
        }

        // Bare Shift key toggles Chinese/English mode (on key release, only if no other key was pressed)
        if event.type == .flagsChanged {
            let result = shiftTracker.handleFlagsChanged(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
            if result == .shouldToggle {
                toggleEnglishMode(client: sender)
                return true
            }
            return false
        }

        // Track Shift usage for bare-Shift detection, including clients that emit keyUp/keyDown
        if event.type == .keyUp {
            if shiftTracker.handleKeyUp(keyCode: event.keyCode) == .shouldToggle {
                toggleEnglishMode(client: sender)
                return true
            }
            return false
        }

        if event.type == .keyDown {
            shiftTracker.handleKeyDown(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
            if event.keyCode == kVK_Shift || event.keyCode == kVK_RightShift {
                return false
            }
        }

        if event.type == NSEvent.EventType.keyDown {

            guard let inputString = event.characters, let key = inputString.first else {
                return false
            }

            let context = InputContext.shared
            switch MixedKeyAction.resolve(event: event, context: context) {
            case .passThrough:
                return false
            case .acceptEnglish(let index):
                context.currentIndex = index
                commitCandidate(client: sender)
                return true
            case .insertEnglishSpace:
                if context.composeString.count < 120 {
                    context.composeString.append(" ")
                    updateCandidatesWindow()
                } else {
                    commitComposedString(client: sender)
                    client().insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))
                }
                return true
            case .finishLiteral(let consumeKey):
                commitComposedString(client: sender)
                return consumeKey
            case .none:
                break
            }

            NSLog("key=\(Utilities.TranslateKey(event)), keyCode=\(event.keyCode)")

            if inputString.unicodeScalars.allSatisfy({ (65...90).contains($0.value) || (97...122).contains($0.value) }) {
                InputContext.shared.composeString.append(inputString)
                updateCandidatesWindow()
                return true
            }

            // Single quote as pinyin syllable separator (e.g. xi'an → 西安)
            else if key == "'" && InputContext.shared.composeString.count > 0
                && !InputContext.shared.composeString.hasSuffix("'")
            {
                InputContext.shared.composeString.append("'")
                updateCandidatesWindow()
                return true
            }

            else if let keyValue = Int(inputString), (0...9).contains(keyValue) {
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

            else if event.keyCode == kVK_Space && !InputContext.shared.composeString.isEmpty {
                if InputContext.shared.candidates.isEmpty {
                    // Confirm this revision only, once its candidates arrive.
                    InputContext.shared.pendingSpace = true
                } else {
                    commitCandidate(client: sender)
                }
                return true
            }

            else if event.keyCode == kVK_Escape && !InputContext.shared.composeString.isEmpty {
                InputContext.shared.clean()
                CompositionText(string: "").apply(to: client())
                uiManager.reset()
                return true
            }

            else {
                if UISettings.fullWidthPunctuation,
                    let fullWidth = PunctuationMap.fullWidth(for: key)
                {
                    if InputContext.shared.candidates.count > 0 {
                        commitCandidate(client: sender)
                    } else if InputContext.shared.composeString.count > 0 {
                        commitComposedString(client: sender)
                    }
                    let range = NSMakeRange(NSNotFound, 0)
                    client().insertText(fullWidth, replacementRange: range)
                    return true
                }
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
