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

    static let shared = CandidatesWindow()

    var _view: CandidatesView

    // Drag offset relative to caret position, persists across updates
    private var dragOffset: NSPoint = .zero
    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        self._view = CandidatesView()

        super.init(
            contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless,
            backing: backingStoreType, defer: flag)

        self.isOpaque = false
        self.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        self.backgroundColor = NSColor.clear
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self._view = CandidatesView.init(frame: self.frame)
        self.contentView = _view
        self.orderFront(nil)
    }

    override var canBecomeKey: Bool { return true }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = self.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let current = NSEvent.mouseLocation
        let newOrigin = NSMakePoint(
            dragStartOrigin.x + (current.x - dragStartMouse.x),
            dragStartOrigin.y + (current.y - dragStartMouse.y))
        self.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            let current = NSEvent.mouseLocation
            dragOffset.x += current.x - dragStartMouse.x
            dragOffset.y += current.y - dragStartMouse.y
            isDragging = false
        }
    }

    func update(sender: IMKTextInput) {
        let caretPosition = self.getCaretPosition(sender: sender)
        let size = self._view.preferredSize

        var rect: NSRect = NSZeroRect

        if size.width > 0 {
            rect = NSMakeRect(
                caretPosition.x + dragOffset.x,
                caretPosition.y - size.height + dragOffset.y,
                size.width,
                size.height)
        }

        NSLog(
            "CandidatesWindow::update rect: (%.0f, %.0f, %.0f, %.0f)",
            rect.origin.x, rect.origin.y, rect.width, rect.height)

        // Don't reposition while user is dragging
        if !isDragging {
            self.setFrame(rect, display: true)
        }

        // force candidate view to redraw
        self._view.needsDisplay = true
    }

    func getCaretPosition(sender: IMKTextInput) -> NSPoint {
        var pos: NSPoint
        var lineHeightRect = NSRect.zero

        withUnsafeMutablePointer(to: &lineHeightRect) { ptr in
            _ = sender.attributes(forCharacterIndex: 0, lineHeightRectangle: ptr)
        }

        pos = NSMakePoint(lineHeightRect.origin.x, lineHeightRect.origin.y)

        return pos
    }

    func show() {
        self.setIsVisible(true)
    }

    func hide() {
        self.setIsVisible(false)
    }
}
