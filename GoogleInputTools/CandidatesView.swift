//
//  CandidatesView.swift
//  GoogleInputTools
//

import Cocoa

class CandidatesView: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    private(set) var candidateText = NSAttributedString(string: "")
    private(set) var selectionRange = NSRange(location: 0, length: 0)
    var maximumWidth: CGFloat = 2000
    private static let selectionPadding: CGFloat = 3

    // Presentation is separate from the selectable model: invalidating a request
    // must not erase the window for one frame or allow an old word to be committed.
    func refresh(context: InputContext) {
        guard !context.composeString.isEmpty else { reset(); return }
        guard !context.isRequestPending else { return }

        let page = context.numberedPageCandidates
        let result = NSMutableAttributedString(
            string: page.isEmpty ? "暂无候选，按回车输入拼音" : page.joined(separator: " "),
            attributes: [.font: UISettings.font, .foregroundColor: UISettings.TextColor])
        let index = context.currentPageIndex
        if page.indices.contains(index) {
            let start = index == 0 ? 0 : page.prefix(index).joined(separator: " ").utf16.count + 1
            selectionRange = NSRange(location: start, length: page[index].utf16.count)
        } else {
            selectionRange = NSRange(location: 0, length: 0)
        }
        var suffix = context.pageIndicator
        if !context.englishCandidateIndices.isEmpty { suffix += "  ⇥ 补全英文" }
        if let indicator = context.candidateSource.indicator { suffix += " " + indicator }
        result.append(NSAttributedString(string: suffix,
            attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.gray]))
        if !candidateText.isEqual(to: result) {
            candidateText = result
        }
        needsDisplay = true
    }

    func reset() {
        candidateText = NSAttributedString(string: "")
        selectionRange = NSRange(location: 0, length: 0)
    }

    private var horizontalInset: CGFloat { UISettings.paddingX + Self.selectionPadding }
    private var verticalInset: CGFloat { UISettings.paddingY + Self.selectionPadding }

    private func layout(width: CGFloat) -> (NSTextStorage, NSLayoutManager, NSTextContainer) {
        let storage = NSTextStorage(attributedString: candidateText)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: max(1, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return (storage, manager, container)
    }

    var preferredSize: NSSize {
        guard candidateText.length > 0 else { return .zero }
        let (storage, manager, container) = layout(width: maximumWidth - horizontalInset * 2)
        return withExtendedLifetime(storage) {
            let rect = manager.usedRect(for: container)
            return NSSize(width: min(maximumWidth, ceil(rect.width) + horizontalInset * 2),
                          height: ceil(rect.height) + verticalInset * 2)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        UISettings.TextBackground.setFill()
        NSBezierPath(rect: bounds).fill()
        guard candidateText.length > 0 else { return }

        let origin = NSPoint(x: horizontalInset, y: verticalInset)
        let (storage, manager, container) = layout(width: bounds.width - horizontalInset * 2)
        withExtendedLifetime(storage) {
            if selectionRange.length > 0 {
                let glyphs = manager.glyphRange(forCharacterRange: selectionRange, actualCharacterRange: nil)
                // A long candidate may span lines on a small display.
                manager.enumerateEnclosingRects(forGlyphRange: glyphs,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { rect, _ in
                    let highlight = rect.offsetBy(dx: origin.x, dy: origin.y)
                        .insetBy(dx: -Self.selectionPadding, dy: -Self.selectionPadding)
                    UISettings.SelectionBackground.setFill()
                    NSBezierPath(roundedRect: highlight, xRadius: 3, yRadius: 3).fill()
                }
            }
            manager.drawGlyphs(forGlyphRange: manager.glyphRange(for: container), at: origin)
        }
    }
}
