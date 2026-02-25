import Cocoa
import ApplicationServices

// MARK: - 智慧截圖模式
enum SmartCaptureMode {
    case window    // 擷取視窗
    case uiElement // 擷取 UI 元素
    case area      // 自由框選
}

// MARK: - 視窗資訊結構
struct WindowInfo {
    let windowId: CGWindowID
    let bounds: CGRect
    let ownerName: String
    let windowName: String
    let layer: Int
}

// MARK: - 智慧截圖管理器
class SmartCaptureManager {
    static let shared = SmartCaptureManager()
    
    private var overlayWindow: SmartCaptureOverlayWindow?
    private var currentMode: SmartCaptureMode = .window
    
    func startCapture(mode: SmartCaptureMode) {
        currentMode = mode
        
        // 隱藏 PinSnap 主視窗（如果有）
        NSApp.hide(nil)
        
        // 延遲顯示 overlay 確保其他視窗已隱藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showOverlay()
        }
    }
    
    private func showOverlay() {
        guard let screen = NSScreen.main else { return }
        
        overlayWindow = SmartCaptureOverlayWindow(
            screenFrame: screen.frame,
            mode: currentMode
        )
        overlayWindow?.onCaptureComplete = { [weak self] rect in
            self?.performCapture(rect: rect)
        }
        overlayWindow?.onCancel = { [weak self] in
            self?.closeOverlay()
        }
        overlayWindow?.makeKeyAndOrderFront(nil)
        
        // 啟動螢幕截取
        overlayWindow?.startCapture()
    }
    
    private func closeOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        NSApp.unhide(nil)
    }
    
    private func performCapture(rect: CGRect) {
        closeOverlay()
        
        let tempDir = NSTemporaryDirectory()
        let tempFileName = UUID().uuidString + ".png"
        let tempFilePath = URL(fileURLWithPath: tempDir).appendingPathComponent(tempFileName).path
        
        // 轉換座標（從 App 座標轉為螢幕座標）
        guard let screen = NSScreen.main else { return }
        let screenRect = CGRect(
            x: rect.origin.x,
            y: screen.frame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", "-R", "\(Int(screenRect.origin.x)),\(Int(screenRect.origin.y)),\(Int(screenRect.width)),\(Int(screenRect.height))", tempFilePath]
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if FileManager.default.fileExists(atPath: tempFilePath) {
                    if let image = NSImage(contentsOfFile: tempFilePath) {
                        self?.createPinnedWindow(with: image)
                    }
                    try? FileManager.default.removeItem(atPath: tempFilePath)
                } else {
                    NSApp.unhide(nil)
                }
            }
        }
        try? task.run()
    }
    
    private func createPinnedWindow(with image: NSImage) {
        // 使用 CaptureManager 來建立釘選視窗
        let controller = PinnedImageWindowController(image: image)
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window, queue: nil) { _ in
            NSApp.unhide(nil)
        }
        
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - 視窗偵測
    func getWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [WindowInfo] = []
        
        for window in windowList {
            guard let windowId = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let layer = window[kCGWindowLayer as String] as? Int else {
                continue
            }
            
            // 過濾系統視窗和選單
            if layer < 0 || layer > 100 { continue }
            if ownerName == "Window Server" || ownerName == "Dock" || ownerName == "SystemUIServer" { continue }
            
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            // 過濾太小的視窗
            if bounds.width < 50 || bounds.height < 50 { continue }
            
            let windowName = window[kCGWindowName as String] as? String ?? ""
            
            windows.append(WindowInfo(
                windowId: windowId,
                bounds: bounds,
                ownerName: ownerName,
                windowName: windowName,
                layer: layer
            ))
        }
        
        return windows.sorted { $0.layer > $1.layer }
    }
    
    // MARK: - UI 元素偵測 (Accessibility API)
    func getUIElementAtPoint(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        
        if result == .success {
            return element
        }
        return nil
    }
    
    func getElementBounds(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        var positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        var sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if positionResult == .success, let posValue = positionValue {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        }
        
        if sizeResult == .success, let szValue = sizeValue {
            AXValueGetValue(szValue as! AXValue, .cgSize, &size)
        }
        
        if positionResult == .success && sizeResult == .success {
            return CGRect(origin: position, size: size)
        }
        
        return nil
    }
    
    func getElementTitle(_ element: AXUIElement) -> String? {
        var title: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        if result == .success, let titleString = title as? String {
            return titleString
        }
        return nil
    }
}

// MARK: - 智慧截圖浮動視窗
class SmartCaptureOverlayWindow: NSWindow {
    private let overlayView: SmartCaptureOverlayView
    private let captureMode: SmartCaptureMode
    private var trackingArea: NSTrackingArea?
    
    var onCaptureComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    init(screenFrame: CGRect, mode: SmartCaptureMode) {
        self.captureMode = mode
        self.overlayView = SmartCaptureOverlayView(frame: screenFrame, mode: mode)
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.contentView = overlayView
    }
    
    func startCapture() {
        overlayView.onAreaSelected = { [weak self] rect in
            self?.onCaptureComplete?(rect)
        }
        
        overlayView.onCancel = { [weak self] in
            self?.onCancel?()
        }
    }
    
    override var canBecomeKey: Bool { true }
}

// MARK: - 智慧截圖覆蓋視圖
class SmartCaptureOverlayView: NSView {
    private let mode: SmartCaptureMode
    private var highlightedRect: CGRect?
    private var selectionRect: CGRect?
    private var isDragging = false
    private var dragStartPoint: CGPoint?
    
    private let highlightLayer = CAShapeLayer()
    private let dimView = NSView()
    private let selectionLayer = CAShapeLayer()
    private let instructionLabel = NSTextField()
    
    var onAreaSelected: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    init(frame: NSRect, mode: SmartCaptureMode) {
        self.mode = mode
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        // 暗色遮罩
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        dimView.frame = bounds
        addSubview(dimView)
        
        // 高亮層
        highlightLayer.fillColor = NSColor.clear.cgColor
        highlightLayer.strokeColor = NSColor.systemBlue.cgColor
        highlightLayer.lineWidth = 2
        layer?.addSublayer(highlightLayer)
        
        // 選取層
        selectionLayer.fillColor = NSColor.clear.cgColor
        selectionLayer.strokeColor = NSColor.white.cgColor
        selectionLayer.lineWidth = 2
        selectionLayer.lineDashPattern = [5, 5]
        layer?.addSublayer(selectionLayer)
        
        // 說明文字
        instructionLabel.isBordered = false
        instructionLabel.isEditable = false
        instructionLabel.drawsBackground = true
        instructionLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        instructionLabel.textColor = .white
        instructionLabel.alignment = .center
        instructionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        
        let instructionText: String
        switch mode {
        case .window:
            instructionText = "點擊視窗以擷取 • 按 ESC 取消"
        case .uiElement:
            instructionText = "將滑鼠懸停在 UI 元素上然後點擊 • 按 ESC 取消"
        case .area:
            instructionText = "拖曳滑鼠框選範圍 • 按 ESC 取消"
        }
        
        instructionLabel.stringValue = instructionText
        instructionLabel.sizeToFit()
        instructionLabel.frame.size.width += 40
        instructionLabel.frame.size.height += 20
        instructionLabel.frame.origin = CGPoint(
            x: (bounds.width - instructionLabel.frame.width) / 2,
            y: bounds.height - 60
        )
        addSubview(instructionLabel)
        
        // 監聽滑鼠移動
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        switch event.type {
        case .mouseMoved:
            handleMouseMoved(at: point)
        case .leftMouseDown:
            handleMouseDown(at: point)
        case .leftMouseDragged:
            handleMouseDragged(at: point)
        case .leftMouseUp:
            handleMouseUp(at: point)
        case .keyDown:
            if event.keyCode == 53 { // ESC
                onCancel?()
            }
        default:
            break
        }
    }
    
    private func handleMouseMoved(at point: CGPoint) {
        guard mode != .area else { return }
        
        var foundRect: CGRect?
        
        switch mode {
        case .window:
            // 偵測視窗
            let windows = SmartCaptureManager.shared.getWindows()
            for window in windows {
                if window.bounds.contains(point) {
                    foundRect = window.bounds
                    break
                }
            }
        case .uiElement:
            // 偵測 UI 元素
            if let element = SmartCaptureManager.shared.getUIElementAtPoint(point),
               let bounds = SmartCaptureManager.shared.getElementBounds(element) {
                foundRect = bounds
            }
        case .area:
            break
        }
        
        highlightedRect = foundRect
        updateHighlight()
    }
    
    private func handleMouseDown(at point: CGPoint) {
        if mode == .area {
            isDragging = true
            dragStartPoint = point
            selectionRect = CGRect(origin: point, size: .zero)
        } else {
            if let rect = highlightedRect {
                onAreaSelected?(rect)
            }
        }
    }
    
    private func handleMouseDragged(at point: CGPoint) {
        guard mode == .area, isDragging, let startPoint = dragStartPoint else { return }
        
        let rect = CGRect(
            x: min(startPoint.x, point.x),
            y: min(startPoint.y, point.y),
            width: abs(point.x - startPoint.x),
            height: abs(point.y - startPoint.y)
        )
        
        selectionRect = rect
        updateSelection()
    }
    
    private func handleMouseUp(at point: CGPoint) {
        guard mode == .area, isDragging else { return }
        
        isDragging = false
        
        if let rect = selectionRect, rect.width > 10, rect.height > 10 {
            onAreaSelected?(rect)
        } else {
            selectionRect = nil
            updateSelection()
        }
        
        dragStartPoint = nil
    }
    
    private func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if let rect = highlightedRect {
            let path = CGPath(rect: rect, transform: nil)
            highlightLayer.path = path
            highlightLayer.isHidden = false
            
            // 創建高亮動畫
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1.0
            animation.toValue = 0.5
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            highlightLayer.add(animation, forKey: "pulse")
        } else {
            highlightLayer.isHidden = true
            highlightLayer.removeAllAnimations()
        }
        
        CATransaction.commit()
    }
    
    private func updateSelection() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if let rect = selectionRect {
            let path = CGPath(rect: rect, transform: nil)
            selectionLayer.path = path
            selectionLayer.isHidden = false
        } else {
            selectionLayer.isHidden = true
        }
        
        CATransaction.commit()
    }
}
