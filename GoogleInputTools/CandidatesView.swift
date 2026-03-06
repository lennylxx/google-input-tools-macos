//
//  CandidatesView.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import SwiftUI

class CandidatesView: NSView {

    override var isFlipped: Bool { true }

    private var selectionRange: NSRange = NSMakeRange(0, 0)
    private static let selectionPadding: CGFloat = 3
    private static let composeBottomMargin: CGFloat = 4

    private func buildComposeText() -> NSAttributedString? {
        let composeString = InputContext.shared.composeString
        if composeString.isEmpty { return nil }
        return NSAttributedString(
            string: composeString,
            attributes: [
                .font: UISettings.font,
                .foregroundColor: NSColor.systemOrange,
            ])
    }

    private func buildCandidateText() -> NSMutableAttributedString {
        let context = InputContext.shared
        let result = NSMutableAttributedString()

        let pageCandidates = context.numberedPageCandidates
        let candidateText = pageCandidates.joined(separator: " ")

        result.append(
            NSAttributedString(
                string: candidateText,
                attributes: [
                    .font: UISettings.font,
                    .foregroundColor: UISettings.TextColor,
                ]))

        // Track selection range within candidate text
        var start = 0
        let pageIndex = context.currentPageIndex
        if pageIndex > 0 {
            start = pageCandidates.prefix(pageIndex).joined(separator: " ").count + 1
        }

        let selection = context.currentNumberedPageCandidate
        if selection.count > 0 {
            selectionRange = NSMakeRange(start, selection.count)
        } else {
            selectionRange = NSMakeRange(0, 0)
        }

        // Append trailing indicators
        var suffix = context.pageIndicator
        if let sourceIndicator = context.candidateSource.indicator {
            suffix += " " + sourceIndicator
        }
        if !suffix.isEmpty {
            result.append(
                NSAttributedString(
                    string: suffix,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: NSColor.gray,
                    ]))
        }

        return result
    }

    private func measureText(_ text: NSAttributedString) -> NSSize {
        let rect = text.boundingRect(
            with: NSSize(width: CGFloat(2000), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        return NSMakeSize(ceil(rect.width), ceil(rect.height))
    }

    var preferredSize: NSSize {
        let pad = Self.selectionPadding
        let px = UISettings.paddingX
        let py = UISettings.paddingY

        let composeText = buildComposeText()
        let candidateText = buildCandidateText()
        if candidateText.length == 0 { return .zero }

        let candidateSize = measureText(candidateText)
        var contentWidth = candidateSize.width
        var contentHeight = pad + candidateSize.height + pad

        if let ct = composeText {
            let composeSize = measureText(ct)
            contentWidth = max(contentWidth, composeSize.width)
            contentHeight = composeSize.height + Self.composeBottomMargin + contentHeight
        }

        return NSMakeSize(
            contentWidth + (px + pad) * 2,
            contentHeight + py * 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSLog("CandidatesView::draw")

        let bounds: NSRect = self.bounds
        UISettings.TextBackground.set()
        NSBezierPath.fill(bounds)

        let pad = Self.selectionPadding
        let px = UISettings.paddingX
        let py = UISettings.paddingY

        let composeText = buildComposeText()
        let candidateText = buildCandidateText()
        if candidateText.length == 0 { return }

        var y = py

        // Upper box: compose string
        if let ct = composeText {
            ct.draw(at: NSPoint(x: px + pad, y: y))
            y += measureText(ct).height + Self.composeBottomMargin
        }

        // Lower box: candidates with selection highlight
        let candidateOrigin = NSPoint(x: px + pad, y: y + pad)
        let candidateSize = NSSize(
            width: bounds.width - (px + pad) * 2,
            height: bounds.height - y - pad - py)

        let textStorage = NSTextStorage(attributedString: candidateText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: candidateSize)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        if selectionRange.length > 0 {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: selectionRange, actualCharacterRange: nil)
            var selRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: textContainer)

            selRect.origin.x += candidateOrigin.x - pad
            selRect.origin.y += candidateOrigin.y - pad
            selRect.size.width += pad * 2
            selRect.size.height += pad * 2

            UISettings.SelectionBackground.setFill()
            let path = NSBezierPath(roundedRect: selRect, xRadius: 3, yRadius: 3)
            path.fill()
        }

        let fullGlyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawGlyphs(forGlyphRange: fullGlyphRange, at: candidateOrigin)
    }
}
