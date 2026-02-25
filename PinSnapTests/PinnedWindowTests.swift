import XCTest
@testable import PinSnap

final class PinnedWindowTests: XCTestCase {

    var window: PinnedWindow!

    override func setUp() {
        super.setUp()
        window = PinnedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    func testCanBecomeKey_returnsTrue() {
        XCTAssertTrue(window.canBecomeKey)
    }

    func testCanBecomeMain_returnsTrue() {
        XCTAssertTrue(window.canBecomeMain)
    }

    func testAcceptsFirstResponder_returnsTrue() {
        XCTAssertTrue(window.acceptsFirstResponder)
    }

    func testOnCopyCommand_initiallyNil() {
        XCTAssertNil(window.onCopyCommand)
    }

    func testOnSaveCommand_initiallyNil() {
        XCTAssertNil(window.onSaveCommand)
    }

    func testOnCopyCommand_canBeSet() {
        var called = false
        window.onCopyCommand = {
            called = true
        }
        
        XCTAssertNotNil(window.onCopyCommand)
        window.onCopyCommand?()
        XCTAssertTrue(called)
    }

    func testOnSaveCommand_canBeSet() {
        var called = false
        window.onSaveCommand = {
            called = true
        }
        
        XCTAssertNotNil(window.onSaveCommand)
        window.onSaveCommand?()
        XCTAssertTrue(called)
    }

    func testDragStartLocation_initiallyNil() {
        XCTAssertNil(window.dragStartLocation)
    }

    func testDragStartLocation_canBeSet() {
        let point = NSPoint(x: 100, y: 100)
        window.dragStartLocation = point
        
        XCTAssertEqual(window.dragStartLocation, point)
    }

}
