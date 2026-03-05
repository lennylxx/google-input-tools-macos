//
//  CustomUICandidateManager.swift
//  GoogleInputTools
//
//  Created by lennylxx on 3/5/26.
//

import InputMethodKit

class CustomUICandidateManager: CandidateUIManager {

    func show() {
        CandidatesWindow.shared.show()
    }

    func hide() {
        CandidatesWindow.shared.hide()
    }

    func updateCandidates(client: IMKTextInput) {
        CandidatesWindow.shared.update(sender: client)
    }

    func handleArrowKey(event: NSEvent, client: IMKTextInput) {
        let context = InputContext.shared
        let pageStart = context.currentPage * context.pageSize
        let pageEnd = min(pageStart + context.pageSize, context.candidates.count) - 1

        if event.keyCode == kVK_LeftArrow && context.currentIndex > pageStart {
            context.currentIndex -= 1
        }

        if event.keyCode == kVK_RightArrow && context.currentIndex < pageEnd {
            context.currentIndex += 1
        }

        // keep the marked text unchanged
        let compString = context.composeString
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client.setMarkedText(compString, selectionRange: range, replacementRange: range)
        CandidatesWindow.shared.update(sender: client)
    }

    func pageUp(sender: Any?, client: IMKTextInput) {
        let context = InputContext.shared
        if context.currentPage > 0 {
            context.currentPage -= 1
            context.currentIndex = context.currentPage * context.pageSize
            CandidatesWindow.shared.update(sender: client)
        }
    }

    func pageDown(sender: Any?, client: IMKTextInput) {
        let context = InputContext.shared
        if context.currentPage < context.totalPages - 1 {
            context.currentPage += 1
            context.currentIndex = context.currentPage * context.pageSize
            CandidatesWindow.shared.update(sender: client)
        }
    }

    func selectByNumber(keyValue: Int) -> Bool {
        let context = InputContext.shared
        let pageCandidates = context.currentPageCandidates

        NSLog("keyValue=\(keyValue), page=\(context.currentPage), pageCount=\(pageCandidates.count)")

        if keyValue >= 1 && keyValue <= pageCandidates.count {
            context.currentIndex = context.absoluteIndex(forPageIndex: keyValue - 1)
            return true
        }
        return false
    }

    func reset() {
        InputContext.shared.currentIndex = 0
        CandidatesWindow.shared.hide()
    }
}
