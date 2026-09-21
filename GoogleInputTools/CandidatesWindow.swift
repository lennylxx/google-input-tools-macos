//
//  CandidatesWindow.swift
//  GoogleInputTools
//

import Cocoa
import InputMethodKit

// All coordinates are AppKit global screen coordinates, including negative
// origins on secondary displays. Keep a small gap from the active text line.
enum CandidateWindowPlacement {
    static let margin: CGFloat = 4

    static func screenIndex(for caret: NSRect, frames: [NSRect]) -> Int? {
        let point = NSPoint(x: caret.midX, y: caret.midY)
        return frames.firstIndex(where: { $0.contains(point) })
    }

    static func frame(size: NSSize, caret: NSRect, visibleFrame: NSRect,
                      offset: NSPoint = .zero) -> NSRect {
        let available = visibleFrame.insetBy(dx: margin, dy: margin)
        let width = min(size.width, available.width)
        let height = min(size.height, available.height)
        let x = min(max(caret.minX + offset.x, available.minX), available.maxX - width)
        let below = caret.minY - margin - height + offset.y
        let above = caret.maxY + margin + offset.y
        let y = below >= available.minY ? below : above
        return NSRect(x: x, y: min(max(y, available.minY), available.maxY - height),
                      width: width, height: height)
    }

    static func isValidCaret(_ rect: NSRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy { $0.isFinite }
            && rect.height > 0
    }

    static func caretRect(visibleFrames: [NSRect], inlineRect: (Int) -> NSRect) -> NSRect? {
        // This is IMK's candidate-positioning API. Index zero anchors the active
        // marked session and is supported by clients that cannot map document
        // offsets through firstRectForCharacterRange. Do not query one past the
        // last character or substitute the document API's placeholder rectangle.
        let rect = inlineRect(0)
        guard isValidCaret(rect),
              screenIndex(for: rect.standardized, frames: visibleFrames) != nil else { return nil }
        return rect.standardized
    }
}

class CandidatesWindow: NSWindow {
    static let shared = CandidatesWindow()
    let _view = CandidatesView()

    private var dragOffset: NSPoint = .zero
    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var lastCaret: NSRect?
    private var compositionSize: NSSize = .zero

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: backingStoreType, defer: flag)
        isOpaque = true
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        backgroundColor = UISettings.TextBackground
        animationBehavior = .none
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = _view
        // Stay hidden until the first nonempty presentation is ready.
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let current = NSEvent.mouseLocation
        var origin = NSPoint(x: dragStartOrigin.x + current.x - dragStartMouse.x,
                             y: dragStartOrigin.y + current.y - dragStartMouse.y)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(current) }) {
            let bounds = screen.visibleFrame.insetBy(dx: 4, dy: 4)
            origin.x = min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - frame.width))
            origin.y = min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - frame.height))
        }
        setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        dragOffset.x += frame.minX - dragStartOrigin.x
        dragOffset.y += frame.minY - dragStartOrigin.y
        isDragging = false
    }

    func update(sender: IMKTextInput) {
        let context = InputContext.shared
        _view.refresh(context: context)
        guard !context.composeString.isEmpty else { hide(); return }
        guard let caret = getCaretRect(sender: sender) ?? lastCaret else { return }
        let screens = NSScreen.screens
        guard let index = CandidateWindowPlacement.screenIndex(for: caret, frames: screens.map(\.visibleFrame)) else { return }
        let visibleFrame = screens[index].visibleFrame
        _view.maximumWidth = visibleFrame.width - CandidateWindowPlacement.margin * 2
        let preferred = _view.preferredSize
        guard preferred.width > 0 else { return }
        lastCaret = caret
        // Do not shrink on every keystroke or response. Reset size after commit.
        compositionSize = NSSize(width: max(compositionSize.width, preferred.width),
                                 height: max(compositionSize.height, preferred.height))
        let rect = CandidateWindowPlacement.frame(size: compositionSize, caret: caret,
                                                  visibleFrame: visibleFrame, offset: dragOffset)
        if !isDragging && frame != rect {
            setFrame(rect, display: false, animate: false)
        }
        _view.displayIfNeeded()
    }

    func getCaretRect(sender: IMKTextInput) -> NSRect? {
        return CandidateWindowPlacement.caretRect(visibleFrames: NSScreen.screens.map(\.visibleFrame),
            inlineRect: { index in
                var rect = NSRect.zero
                _ = sender.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
                return rect
            })
    }

    func show() {
        guard _view.candidateText.length > 0, lastCaret != nil, !isVisible else { return }
        orderFrontRegardless()
    }

    func hide() {
        if isVisible { orderOut(nil) }
        _view.reset()
        lastCaret = nil
        compositionSize = .zero
        dragOffset = .zero
        isDragging = false
    }
}
