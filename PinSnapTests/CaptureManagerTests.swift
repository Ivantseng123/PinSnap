import XCTest
@testable import PinSnap

final class CaptureManagerTests: XCTestCase {

    func testSharedInstance_returnsSameInstance() {
        let instance1 = CaptureManager.shared
        let instance2 = CaptureManager.shared
        XCTAssertTrue(instance1 === instance2)
    }

    func testActiveControllers_startsEmpty() {
        let manager = CaptureManager.shared
        XCTAssertTrue(manager.activeControllers.isEmpty)
    }

    func testGenerateFileName_format() {
        let controller = PinnedImageWindowController(image: NSImage())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let expectedPrefix = "PinSnap_"
        let expectedSuffix = ".png"
        
        let fileName = controller.generateFileName()
        
        XCTAssertTrue(fileName.hasPrefix(expectedPrefix))
        XCTAssertTrue(fileName.hasSuffix(expectedSuffix))
        let dateString = String(fileName.dropFirst(expectedPrefix.count).dropLast(expectedSuffix.count))
        XCTAssertNotNil(formatter.date(from: dateString))
    }

}
