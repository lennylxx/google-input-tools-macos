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

    private var shiftKeyUsedWithOtherKey = false

    /// Process a flagsChanged event. Returns whether a toggle should occur.
    func handleFlagsChanged(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Result {
        guard keyCode == kVK_Shift || keyCode == kVK_RightShift else {
            return .none
        }

        if modifierFlags.contains(.shift) {
            // Shift pressed down — start tracking
            shiftKeyUsedWithOtherKey = false
        } else {
            // Shift released — toggle only if no other key was pressed
            if !shiftKeyUsedWithOtherKey {
                return .shouldToggle
            }
        }
        return .none
    }

    /// Process a keyDown event. Call this for every keyDown to track Shift usage.
    func handleKeyDown(modifierFlags: NSEvent.ModifierFlags) {
        if modifierFlags.contains(.shift) {
            shiftKeyUsedWithOtherKey = true
        }
    }
}
