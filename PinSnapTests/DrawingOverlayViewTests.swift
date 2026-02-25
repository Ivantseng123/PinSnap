import XCTest
@testable import PinSnap

final class DrawingOverlayViewTests: XCTestCase {

    var drawingView: DrawingOverlayView!

    override func setUp() {
        super.setUp()
        drawingView = DrawingOverlayView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        drawingView.baseSize = CGSize(width: 100, height: 100)
    }

    override func tearDown() {
        drawingView = nil
        super.tearDown()
    }

    func testUndoLastStroke_removesLastStroke() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 10, y: 10))
        path.line(to: NSPoint(x: 20, y: 20))
        
        drawingView.strokes.append((path: path, color: .red))
        XCTAssertEqual(drawingView.strokes.count, 1)
        
        drawingView.undoLastStroke()
        
        XCTAssertTrue(drawingView.strokes.isEmpty)
    }

    func testUndoLastStroke_emptyStrokes() {
        XCTAssertTrue(drawingView.strokes.isEmpty)
        
        drawingView.undoLastStroke()
        
        XCTAssertTrue(drawingView.strokes.isEmpty)
    }

    func testUndoLastStroke_multipleStrokes() {
        let path1 = NSBezierPath()
        let path2 = NSBezierPath()
        
        drawingView.strokes.append((path: path1, color: .red))
        drawingView.strokes.append((path: path2, color: .blue))
        
        XCTAssertEqual(drawingView.strokes.count, 2)
        
        drawingView.undoLastStroke()
        
        XCTAssertEqual(drawingView.strokes.count, 1)
    }

    func testNormalizePoint_scalesCoordinates() {
        drawingView.baseSize = CGSize(width: 200, height: 200)
        drawingView.bounds = NSRect(x: 0, y: 0, width: 100, height: 100)
        
        let point = NSPoint(x: 50, y: 50)
        let normalized = drawingView.normalize(point)
        
        XCTAssertEqual(normalized.x, 100, accuracy: 0.001)
        XCTAssertEqual(normalized.y, 100, accuracy: 0.001)
    }

    func testNormalizePoint_zeroBounds() {
        drawingView.baseSize = CGSize(width: 200, y: 200)
        drawingView.bounds = NSRect(x: 0, y: 0, width: 0, height: 0)
        
        let point = NSPoint(x: 50, y: 50)
        let normalized = drawingView.normalize(point)
        
        XCTAssertEqual(normalized.x, 0, accuracy: 0.001)
        XCTAssertEqual(normalized.y, 0, accuracy: 0.001)
    }

    func testHitTest_drawingModeDisabled() {
        drawingView.isDrawingMode = false
        
        let result = drawingView.hitTest(NSPoint(x: 50, y: 50))
        
        XCTAssertNil(result)
    }

    func testHitTest_drawingModeEnabled() {
        drawingView.isDrawingMode = true
        
        let result = drawingView.hitTest(NSPoint(x: 50, y: 50))
        
        XCTAssertNotNil(result)
    }

    func testHitTest_topAreaReturnsNil() {
        drawingView.isDrawingMode = true
        drawingView.bounds = NSRect(x: 0, y: 0, width: 100, height: 100)
        
        let result = drawingView.hitTest(NSPoint(x: 50, y: 90))
        
        XCTAssertNil(result)
    }

    func testRenderOn_returnsNSImage() {
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        
        let result = drawingView.renderOn(image: testImage)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.size, testImage.size)
    }

    func testRenderOn_compositesStrokes() {
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 10, y: 10))
        path.line(to: NSPoint(x: 90, y: 90))
        
        drawingView.strokes.append((path: path, color: .red))
        drawingView.baseSize = CGSize(width: 100, height: 100)
        
        let result = drawingView.renderOn(image: testImage)
        
        XCTAssertNotNil(result)
        XCTAssertFalse(drawingView.strokes.isEmpty)
    }

    func testStrokeColor_defaultIsRed() {
        XCTAssertEqual(drawingView.strokeColor, .systemRed)
    }

    func testBaseSize_defaultIsOneByOne() {
        XCTAssertEqual(drawingView.baseSize.width, 1)
        XCTAssertEqual(drawingView.baseSize.height, 1)
    }

    func testCurrentPath_startsNil() {
        XCTAssertNil(drawingView.currentPath)
    }

}
