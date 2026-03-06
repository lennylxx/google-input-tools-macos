//
//  CandidatesView.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import SwiftUI

class CandidatesView: NSView {

    // Build the display text from current InputContext state
    private func buildDisplayText() -> NSMutableAttributedString {
        let context = InputContext.shared
        let pageCandidates = context.numberedPageCandidates
        let candidateText = pageCandidates.joined(separator: " ")
        let textToPaint = NSMutableAttributedString(string: candidateText)

        let globalAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UISettings.font,
            NSAttributedString.Key.foregroundColor: UISettings.TextColor,
        ]

        textToPaint.addAttributes(globalAttributes, range: NSMakeRange(0, candidateText.count))

        // Highlight only the candidate text (not the "N. " prefix)
        var start = 0
        let pageIndex = context.currentPageIndex
        if pageIndex > 0 {
            start = pageCandidates.prefix(pageIndex).joined(separator: " ").count + 1
        }

        let selection = context.currentNumberedPageCandidate
        let prefix = "\(pageIndex + 1). "

        if selection.count > 0 {
            let selectionAttributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key.backgroundColor: UISettings.SelectionBackground
            ]
            textToPaint.addAttributes(
                selectionAttributes, range: NSMakeRange(start + prefix.count, selection.count - prefix.count))
        }

        // Append trailing indicators (page arrows, network icon) at a fixed small size
        let indicatorFont = NSFont.systemFont(ofSize: 10)
        let indicatorAttributes: [NSAttributedString.Key: Any] = [
            .font: indicatorFont,
            .foregroundColor: NSColor.gray,
        ]

        var suffix = context.pageIndicator
        if let sourceIndicator = context.candidateSource.indicator {
            suffix += " " + sourceIndicator
        }

        if !suffix.isEmpty {
            let indicatorStr = NSAttributedString(string: suffix, attributes: indicatorAttributes)
            textToPaint.append(indicatorStr)
        }

        return textToPaint
    }

    var preferredSize: NSSize {
        let textToPaint = buildDisplayText()
        if textToPaint.length == 0 { return .zero }
        return NSMakeSize(
            textToPaint.size().width + UISettings.paddingX * 2,
            textToPaint.size().height + UISettings.paddingY * 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSLog("CandidatesView::draw")

        let bounds: NSRect = self.bounds
        UISettings.TextBackground.set()
        NSBezierPath.fill(bounds)

        let textToPaint = buildDisplayText()

        let textBounds = NSMakeRect(
            bounds.origin.x + UISettings.paddingX,
            bounds.origin.y + UISettings.paddingY,
            bounds.width - UISettings.paddingX * 2,
            bounds.height - UISettings.paddingY * 2)

        textToPaint.draw(in: textBounds)
    }
}
