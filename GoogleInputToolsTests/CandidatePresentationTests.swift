import Cocoa
import XCTest
@testable import GoogleInputTools

class CandidatePresentationTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 24, width: 1440, height: 876)

    func testRightEdgeMovesWholeWindowLeft() {
        let caret = NSRect(x: 1435, y: 300, width: 1, height: 22)
        let rect = CandidateWindowPlacement.frame(size: NSSize(width: 420, height: 44),
                                                  caret: caret, visibleFrame: screen)
        XCTAssertEqual(rect.maxX, screen.maxX - 4)
        XCTAssertEqual(rect.maxY, caret.minY - 4)
        XCTAssertTrue(screen.contains(rect))
    }

    func testBottomEdgeFlipsAboveTextLine() {
        let caret = NSRect(x: 800, y: 30, width: 1, height: 24)
        let rect = CandidateWindowPlacement.frame(size: NSSize(width: 400, height: 44),
                                                  caret: caret, visibleFrame: screen)
        XCTAssertEqual(rect.minY, caret.maxY + 4)
        XCTAssertTrue(screen.contains(rect))
    }

    func testSecondaryDisplayWithNegativeOriginAndOversizeWindow() {
        let secondary = NSRect(x: -1280, y: -160, width: 1280, height: 800)
        let caret = NSRect(x: -30, y: 300, width: 1, height: 24)
        XCTAssertEqual(CandidateWindowPlacement.screenIndex(for: caret, frames: [screen, secondary]), 1)
        let rect = CandidateWindowPlacement.frame(size: NSSize(width: 1700, height: 900),
                                                  caret: caret, visibleFrame: secondary)
        XCTAssertTrue(secondary.contains(rect))
        XCTAssertEqual(rect.width, secondary.width - 8)
    }

    func testCaretUsesSupportedInlineSessionAnchor() {
        var requestedIndices = [Int]()
        let expected = NSRect(x: 45, y: 400, width: 1, height: 24)
        let rect = CandidateWindowPlacement.caretRect(
            visibleFrames: [screen],
            inlineRect: { requestedIndices.append($0); return expected })
        XCTAssertEqual(rect, expected)
        XCTAssertEqual(requestedIndices, [0])
    }

    func testUnsupportedClientGeometryDoesNotMoveToScreenOrigin() {
        var indices = [Int]()
        let rect = CandidateWindowPlacement.caretRect(
            visibleFrames: [screen],
            inlineRect: { indices.append($0); return .zero })
        XCTAssertNil(rect)
        XCTAssertEqual(indices, [0])
    }

    func testNonzeroOffscreenPlaceholderIsRejectedInsteadOfClampedToCorner() {
        for placeholder in [NSRect(x: 0, y: 100000, width: 1, height: 24),
                            NSRect(x: 0, y: 900, width: 1, height: 24),
                            NSRect(x: -100000, y: 300, width: 1, height: 24)] {
            XCTAssertNil(CandidateWindowPlacement.caretRect(visibleFrames: [screen], inlineRect: { _ in placeholder }))
            XCTAssertNil(CandidateWindowPlacement.screenIndex(for: placeholder, frames: [screen]))
        }
    }

    func testAnchorMayBeAtLeftEdgeOrOnNegativeOriginDisplay() {
        let secondary = NSRect(x: -1280, y: -160, width: 1280, height: 800)
        for caret in [NSRect(x: 0, y: 300, width: 0, height: 24),
                      NSRect(x: -1100, y: 400, width: 1, height: 24)] {
            XCTAssertEqual(CandidateWindowPlacement.caretRect(visibleFrames: [screen, secondary],
                                                              inlineRect: { _ in caret }), caret)
        }
    }

    func testInlineAnchorFollowsWrappedComposition() {
        let before = NSRect(x: 1200, y: 400, width: 1, height: 24)
        let after = NSRect(x: 300, y: 376, width: 1, height: 24)
        let size = NSSize(width: 500, height: 44)
        let first = CandidateWindowPlacement.caretRect(visibleFrames: [screen], inlineRect: { _ in before })!
        let next = CandidateWindowPlacement.caretRect(visibleFrames: [screen], inlineRect: { _ in after })!
        let firstFrame = CandidateWindowPlacement.frame(size: size, caret: first, visibleFrame: screen)
        let nextFrame = CandidateWindowPlacement.frame(size: size, caret: next, visibleFrame: screen)
        XCTAssertEqual(nextFrame.minX, after.minX)
        XCTAssertEqual(nextFrame.maxY, after.minY - 4)
        XCTAssertLessThan(nextFrame.maxY, firstFrame.maxY)
    }

    func testPendingRequestKeepsPresentationButInvalidatesSelectableWords() {
        let context = InputContext(pageSize: 9)
        let view = CandidatesView()
        context.composeString = "ni"
        context.acceptCandidates(["你", "拟"], matchedLength: [2, 2], source: .cache, revision: context.revision)
        view.refresh(context: context)
        let oldText = view.candidateText.string
        let oldSize = view.preferredSize
        let oldRevision = context.revision
        context.composeString = "nihao"
        view.refresh(context: context)
        XCTAssertTrue(context.isRequestPending)
        XCTAssertTrue(context.candidates.isEmpty, "Previous candidates must never remain selectable")
        XCTAssertEqual(view.candidateText.string, oldText)
        XCTAssertEqual(view.preferredSize, oldSize, "No zero-size frame between keystrokes")
        XCTAssertFalse(context.acceptCandidates(["你"], matchedLength: [2], source: .network, revision: oldRevision))
        context.acceptCandidates(["你好"], matchedLength: [5], source: .network, revision: context.revision)
        view.refresh(context: context)
        XCTAssertFalse(context.isRequestPending)
        XCTAssertTrue(view.candidateText.string.contains("你好"))
        context.clean()
        view.refresh(context: context)
        XCTAssertEqual(view.preferredSize, .zero)
    }

    func testEmptyCompletedResponseClearsPreviousPresentation() {
        let context = InputContext(pageSize: 9)
        let view = CandidatesView()
        context.composeString = "ni"
        context.acceptCandidates(["你"], matchedLength: nil, source: .cache, revision: context.revision)
        view.refresh(context: context)
        context.composeString = "nix"
        context.acceptCandidates([], matchedLength: nil, source: .network, revision: context.revision)
        view.refresh(context: context)
        XCTAssertFalse(view.candidateText.string.contains("1. 你"))
        XCTAssertTrue(view.candidateText.string.contains("暂无候选"))
    }

    func testLongCandidatesWrapAndSelectionUsesUTF16() throws {
        let context = InputContext(pageSize: 9)
        let view = CandidatesView()
        context.composeString = "ceshi"
        context.acceptCandidates(["🧑‍💻", "这是一个很长的技术词语用于检查候选窗口在窄屏上的换行"],
                                 matchedLength: nil, source: .cache, revision: context.revision)
        context.currentIndex = 1
        view.maximumWidth = 280
        view.refresh(context: context)
        XCTAssertLessThanOrEqual(view.preferredSize.width, 280)
        XCTAssertGreaterThan(view.preferredSize.height, UISettings.fontSize * 2)
        XCTAssertEqual((view.candidateText.string as NSString).substring(with: view.selectionRange),
                       context.currentNumberedPageCandidate)
        view.frame.size = view.preferredSize
        try snapshot(view, name: "GoogleInputTools-candidates-wrapped.png")
    }

    func testInlinePinyinWrapsAndCommitReplacesMarkedText() throws {
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 240, height: 140),
                              styleMask: .borderless, backing: .buffered, defer: false)
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        text.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        text.textContainerInset = .zero
        text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.containerSize = NSSize(width: 240, height: 10000)
        text.textContainer?.widthTracksTextView = true
        // Settle TextKit's layout engine before starting the marked session.
        _ = text.layoutManager
        let prefix = "测试输入测试输入测试输"
        text.string = prefix
        text.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
        window.contentView = text
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let before = text.firstRect(forCharacterRange: text.selectedRange(), actualRange: nil)
        for pinyin in ["n", "ni", "nihao"] {
            let update = CompositionText(string: pinyin)
            text.setMarkedText(update.string, selectedRange: update.selectionRange,
                               replacementRange: update.replacementRange)
            XCTAssertEqual(text.string, prefix + pinyin, "Updates must replace the previous marked text")
        }
        let composition = CompositionText(string: "nihaoshijie")
        text.setMarkedText(composition.string, selectedRange: composition.selectionRange,
                           replacementRange: composition.replacementRange)
        XCTAssertTrue(text.hasMarkedText(), "Marked session immediately after update")
        text.layoutManager?.ensureLayout(for: text.textContainer!)
        XCTAssertTrue(text.hasMarkedText(), "Marked session after layout")
        let after = text.firstRect(forCharacterRange: text.selectedRange(), actualRange: nil)
        XCTAssertTrue(text.hasMarkedText(), "Marked session after caret query")
        XCTAssertEqual(text.string, prefix + composition.string)
        XCTAssertEqual(text.selectedRange().location, text.string.utf16.count)
        XCTAssertLessThan(after.minY, before.minY, "Actual pinyin must move the caret onto the next line")
        let placed = CandidateWindowPlacement.frame(size: NSSize(width: 340, height: 44),
                                                    caret: after, visibleFrame: screen)
        XCTAssertEqual(placed.maxY, after.minY - 4)
        text.insertText("你好世界", replacementRange: composition.replacementRange)
        XCTAssertEqual(text.string, prefix + "你好世界")
        XCTAssertFalse(text.hasMarkedText())
        XCTAssertFalse(text.string.contains("\u{200B}"))
        try snapshot(text, name: "GoogleInputTools-inline-wrap.png")
    }

    private func snapshot(_ view: NSView, name: String) throws {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: view.bounds).fill()
        view.displayIgnoringOpacity(view.bounds, in: graphics)
        NSGraphicsContext.restoreGraphicsState()
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try data.write(to: url)
        print("Layout snapshot: \(url.path)")
    }
}
