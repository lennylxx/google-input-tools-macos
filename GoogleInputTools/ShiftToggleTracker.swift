//
//  ShiftToggleTracker.swift
//  GoogleInputTools
//

import Carbon
import AppKit

/// Tracks bare-Shift key presses to determine when to toggle Chinese/English mode.
/// A "bare Shift" is when Shift is pressed and released without any other key in between.
class ShiftToggleTracker {

    enum Result {
        case none        // No action needed
        case shouldToggle // Bare Shift detected — caller should toggle mode
    }

    private var trackedShiftKeyCode: UInt16?
    private var shiftKeyUsedWithOtherKey = false

    /// Process a flagsChanged event. Returns whether a toggle should occur.
    func handleFlagsChanged(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Result {
        guard isShiftKey(keyCode) else {
            return .none
        }

        if modifierFlags.contains(.shift) {
            startTrackingShift(keyCode)
            return .none
        }

        return finishTrackingShift()
    }

    /// Process a keyDown event. Some clients emit modifier keyDown/keyUp events instead of flagsChanged.
    func handleKeyDown(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        if isShiftKey(keyCode) {
            startTrackingShift(keyCode)
            return
        }

        if trackedShiftKeyCode != nil && modifierFlags.contains(.shift) {
            shiftKeyUsedWithOtherKey = true
        }
    }

    /// Process a keyUp event for clients that do not emit Shift flagsChanged events.
    func handleKeyUp(keyCode: UInt16) -> Result {
        guard isShiftKey(keyCode) else {
            return .none
        }

        return finishTrackingShift()
    }

    private func isShiftKey(_ keyCode: UInt16) -> Bool {
        return keyCode == kVK_Shift || keyCode == kVK_RightShift
    }

    private func startTrackingShift(_ keyCode: UInt16) {
        trackedShiftKeyCode = keyCode
        shiftKeyUsedWithOtherKey = false
    }

    private func finishTrackingShift() -> Result {
        guard trackedShiftKeyCode != nil else {
            return .none
        }

        trackedShiftKeyCode = nil
        defer { shiftKeyUsedWithOtherKey = false }

        return shiftKeyUsedWithOtherKey ? .none : .shouldToggle
    }
}
