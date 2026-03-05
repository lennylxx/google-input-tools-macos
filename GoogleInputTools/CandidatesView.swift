//
//  CandidatesView.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import SwiftUI

class CandidatesView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        NSLog("CandidatesView::draw")

        let bounds: NSRect = self.bounds
        UISettings.TextBackground.set()
        NSBezierPath.fill(bounds)

        let context = InputContext.shared
        let pageCandidates = context.numberedPageCandidates
        let pageInfo = context.totalPages > 1 ? " \(context.currentPage + 1)/\(context.totalPages)" : ""
        let text = pageCandidates.joined(separator: " ") + pageInfo
        let textToPaint: NSMutableAttributedString = NSMutableAttributedString.init(string: text)

        let globalAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UISettings.font,
            NSAttributedString.Key.foregroundColor: UISettings.TextColor,
        ]

        var start = 0
        let pageIndex = context.currentPageIndex
        if pageIndex > 0 {
            start = pageCandidates.prefix(pageIndex).joined(separator: " ").count + 1
        }

        let selection = context.currentNumberedPageCandidate

        let selectionAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.backgroundColor: UISettings.SelectionBackground
        ]

        textToPaint.addAttributes(globalAttributes, range: NSMakeRange(0, text.count))
        if selection.count > 0 {
            textToPaint.addAttributes(
                selectionAttributes, range: NSMakeRange(start, selection.count))
        }

        // calculate text bounds with padding inside the view
        let textBounds = NSMakeRect(
            bounds.origin.x + UISettings.WindowPaddingX,
            bounds.origin.y + UISettings.WindowPaddingY,
            bounds.width - UISettings.WindowPaddingX * 2,
            bounds.height - UISettings.WindowPaddingY * 2)

        NSLog(
            "textBounds: (%.0f, %.0f, %.0f, %.0f)", textBounds.origin.x, textBounds.origin.y,
            textBounds.width, textBounds.height)

        textToPaint.draw(in: textBounds)
    }
}
