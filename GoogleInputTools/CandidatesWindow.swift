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

        let compString = InputEngine.sharedInstance.composeString()
        let compStringToPaint: NSMutableAttributedString = NSMutableAttributedString.init(
            string: compString)

        compStringToPaint.addAttribute(
            NSAttributedString.Key.font, value: NSFont.userFont(ofSize: 16)!,
            range: NSMakeRange(0, compString.count))

        // do not paint by default
        var rect: NSRect = NSZeroRect

        if compString.count > 0 {
            rect = NSMakeRect(
                caretPosition.x, caretPosition.y - compStringToPaint.size().height,
                compStringToPaint.size().width, compStringToPaint.size().height)
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
