//
//  CandidatesWindow.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation
import InputMethodKit
import SwiftUI

class CandidatesWindow: NSWindow {
    var _view: CandidatesView

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        self._view = CandidatesView()

        super.init(
            contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless,
            backing: backingStoreType, defer: flag)

        self.isOpaque = false
        self.level = NSWindow.Level.floating
        self.backgroundColor = NSColor.clear

        self._view = CandidatesView.init(frame: self.frame)
        self.contentView = _view
        self.orderFront(nil)
    }

    func update(sender: IMKTextInput) {
        let caretPosition = self.getCaretPosition(sender: sender)

        let text = InputEngine.shared.candidates().joined(separator: ",")
        let textToPaint: NSMutableAttributedString = NSMutableAttributedString.init(string: text)

        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: NSFont.Weight.regular)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font
        ]

        textToPaint.addAttributes(attributes, range: NSMakeRange(0, text.count))

        // do not paint by default
        var rect: NSRect = NSZeroRect

        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 10

        // calculate candidate window position and size
        if text.count > 0 {
            rect = NSMakeRect(
                caretPosition.x,
                caretPosition.y - textToPaint.size().height - paddingY,
                textToPaint.size().width + paddingX,
                textToPaint.size().height + paddingY)
        }

        NSLog(
            "CandidatesWindow::update rect: (%.0f, %.0f, %.0f, %.0f)",
            rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)

        self.setFrame(rect, display: true)

        // adjust candidate view
        self._view.setNeedsDisplay(rect)
    }

    func getCaretPosition(sender: IMKTextInput) -> NSPoint {
        var pos: NSPoint
        let lineHeightRect: UnsafeMutablePointer<NSRect> = UnsafeMutablePointer<NSRect>.allocate(
            capacity: 1)

        sender.attributes(forCharacterIndex: 0, lineHeightRectangle: lineHeightRect)

        let rect = lineHeightRect.pointee
        pos = NSMakePoint(rect.origin.x, rect.origin.y)

        return pos
    }
}
