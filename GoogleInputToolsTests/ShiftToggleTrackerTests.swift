import XCTest
import Carbon
@testable import GoogleInputTools

class ShiftToggleTrackerTests: XCTestCase {

    var tracker: ShiftToggleTracker!

    override func setUp() {
        super.setUp()
        tracker = ShiftToggleTracker()
    }

    // MARK: - Bare Shift (should toggle)

    func testBareShiftPressAndRelease() {
        // Shift down
        let down = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)
        XCTAssertEqual(down, .none)

        // Shift up with no key in between
        let up = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up, .shouldToggle)
    }

    func testBareRightShiftPressAndRelease() {
        let down = tracker.handleFlagsChanged(keyCode: UInt16(kVK_RightShift), modifierFlags: .shift)
        XCTAssertEqual(down, .none)

        let up = tracker.handleFlagsChanged(keyCode: UInt16(kVK_RightShift), modifierFlags: [])
        XCTAssertEqual(up, .shouldToggle)
    }

    // MARK: - Shift + key (should NOT toggle)

    func testShiftWithKeyDoesNotToggle() {
        // Shift down
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)

        // Key pressed while Shift held
        tracker.handleKeyDown(modifierFlags: .shift)

        // Shift up — should NOT toggle
        let up = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up, .none)
    }

    func testShiftWithMultipleKeysDoesNotToggle() {
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)

        // Multiple keys pressed
        tracker.handleKeyDown(modifierFlags: .shift)
        tracker.handleKeyDown(modifierFlags: .shift)

        let up = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up, .none)
    }

    // MARK: - Consecutive bare Shift toggles

    func testConsecutiveBareShiftToggles() {
        // First bare Shift
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)
        let up1 = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up1, .shouldToggle)

        // Second bare Shift
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)
        let up2 = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up2, .shouldToggle)
    }

    // MARK: - Reset after toggle

    func testStateResetsAfterShiftWithKey() {
        // Shift + key (no toggle)
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)
        tracker.handleKeyDown(modifierFlags: .shift)
        let up1 = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up1, .none)

        // Next bare Shift should toggle
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)
        let up2 = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up2, .shouldToggle)
    }

    // MARK: - Non-Shift modifier keys

    func testNonShiftFlagsChangedIgnored() {
        // Control key (keyCode 0x3B) should be ignored
        let result = tracker.handleFlagsChanged(keyCode: 0x3B, modifierFlags: .control)
        XCTAssertEqual(result, .none)
    }

    func testCommandKeyIgnored() {
        let result = tracker.handleFlagsChanged(keyCode: 0x37, modifierFlags: .command)
        XCTAssertEqual(result, .none)
    }

    // MARK: - KeyDown without Shift

    func testKeyDownWithoutShiftDoesNotAffectTracking() {
        _ = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: .shift)

        // Key pressed without Shift modifier (shouldn't mark as used)
        tracker.handleKeyDown(modifierFlags: [])

        let up = tracker.handleFlagsChanged(keyCode: UInt16(kVK_Shift), modifierFlags: [])
        XCTAssertEqual(up, .shouldToggle)
    }
}
