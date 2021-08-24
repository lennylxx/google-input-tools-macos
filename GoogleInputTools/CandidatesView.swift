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

        let numberedCandidates = InputContext.shared.numberedCandidates
        let text = numberedCandidates.joined(separator: " ")
        let textToPaint: NSMutableAttributedString = NSMutableAttributedString.init(string: text)

        let globalAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UISettings.Font,
            NSAttributedString.Key.foregroundColor: UISettings.TextColor,
        ]

        // TOOD: use arrow key to change current selected candidate
        let current = numberedCandidates.count > 0 ? numberedCandidates[0] : ""

        let selectionAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.backgroundColor: UISettings.SelectionBackground
        ]

        textToPaint.addAttributes(globalAttributes, range: NSMakeRange(0, text.count))
        textToPaint.addAttributes(selectionAttributes, range: NSMakeRange(0, current.count))

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
