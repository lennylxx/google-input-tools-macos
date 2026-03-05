//
//  SystemUICandidateManager.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import InputMethodKit

class SystemUICandidateManager: CandidateUIManager {

    private let candidates: IMKCandidates

    init(server: IMKServer) {
        self.candidates = IMKCandidates(
            server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
    }

    func show() {
        candidates.show(kIMKLocateCandidatesBelowHint)
    }

    func hide() {
        candidates.hide()
    }

    func updateCandidates(client: IMKTextInput) {
        candidates.update()
    }

    func handleArrowKey(event: NSEvent, client: IMKTextInput) {
        candidates.interpretKeyEvents([event])
    }

    func pageUp(sender: Any?, client: IMKTextInput) {
        candidates.pageUp(sender)
    }

    func pageDown(sender: Any?, client: IMKTextInput) {
        candidates.pageDown(sender)
    }

    func selectByNumber(keyValue: Int) -> Bool {
        let context = InputContext.shared
        let index = context.visiblePageStart + keyValue - 1

        NSLog("keyValue=\(keyValue), visiblePageStart=\(context.visiblePageStart), index=\(index)")

        if keyValue >= 1 && index < context.candidates.count {
            context.currentIndex = index
            return true
        }
        return false
    }

    func reset() {
        candidates.update()
        candidates.hide()
    }

    // MARK: - IMKCandidates data source support

    func allCandidates() -> [Any] {
        return InputContext.shared.candidates
    }

    func candidateSelected(_ candidateString: String) {
        let id = InputContext.shared.candidates.firstIndex(of: candidateString) ?? 0
        InputContext.shared.currentIndex = id
    }

    func candidateSelectionChanged(_ candidateString: String) {
        let context = InputContext.shared
        let id = context.candidates.firstIndex(of: candidateString) ?? 0

        if abs(id - context.currentIndex) > 1 {
            context.visiblePageStart = id
        } else if id < context.visiblePageStart {
            context.visiblePageStart = id
        }

        NSLog("candidate=\(candidateString), index=\(id), visiblePageStart=\(context.visiblePageStart)")
        context.currentIndex = id
    }
}
