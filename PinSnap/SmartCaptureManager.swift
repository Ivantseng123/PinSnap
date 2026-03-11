import Cocoa
import ApplicationServices
import ScreenCaptureKit

struct WindowInfo {
    let windowId: CGWindowID
    let bounds: CGRect
    let ownerName: String
    let windowName: String
    let layer: Int
    var scWindow: SCWindow? = nil
    var zOrder: Int = 0
}

class SmartCaptureManager {
    static let shared = SmartCaptureManager()
    
    private var overlayWindow: WindowCaptureOverlayWindow?
    
    func captureWindow() {
        if !hasScreenRecordingPermission() {
            requestScreenRecordingPermission()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showOverlay()
        }
    }
    
    public func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }
    
    public func requestScreenRecordingPermission() {
        if #available(macOS 10.15, *) {
            CGRequestScreenCaptureAccess()
            
            let alert = NSAlert()
            alert.messageText = "需要螢幕錄製權限"
            alert.informativeText = "請在系統偏好設定中允許 PinSnap 進行螢幕錄製，然後再試一次。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "開啟系統偏好設定")
            alert.addButton(withTitle: "取消")
            
            NSApp.activate(ignoringOtherApps: true)
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func showOverlay() {
        guard let screen = NSScreen.main else { return }
        NSApp.activate(ignoringOtherApps: true)
        
        if #available(macOS 13.0, *) {
            Task {
                var bgImage: CGImage? = nil
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    if let display = content.displays.first(where: { $0.frame == screen.frame }) ?? content.displays.first {
                        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                        let config = SCStreamConfiguration()
                        let scale = screen.backingScaleFactor
                        config.width = Int(screen.frame.width * scale)
                        config.height = Int(screen.frame.height * scale)
                        config.showsCursor = false
                        bgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    }
                } catch {
                    print("凍結背景失敗: \(error)")
                }
                
                DispatchQueue.main.async {
                    self.displayOverlayWindow(screenFrame: screen.frame, bgImage: bgImage)
                }
            }
        }
    }
    
    private func displayOverlayWindow(screenFrame: CGRect, bgImage: CGImage?) {
        overlayWindow = WindowCaptureOverlayWindow(screenFrame: screenFrame, bgImage: bgImage)
        overlayWindow?.onCaptureComplete = { [weak self] windowInfo in
            self?.performCapture(windowInfo: windowInfo)
        }
        overlayWindow?.onCancel = { [weak self] in
            self?.closeOverlay()
        }
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.makeFirstResponder(overlayWindow?.contentView)
        overlayWindow?.startCapture()
    }
    
    private func closeOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
    }
    
    private func performCapture(windowInfo: WindowInfo) {
        closeOverlay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if #available(macOS 13.0, *) {
                Task {
                    do {
                        let filter: SCContentFilter
                        let configuration = SCStreamConfiguration()
                        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                        
                        if let scWindow = windowInfo.scWindow {
                            filter = SCContentFilter(desktopIndependentWindow: scWindow)
                            configuration.width = Int(scWindow.frame.width * scale)
                            configuration.height = Int(scWindow.frame.height * scale)
                        } else {
                            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                            guard let display = availableContent.displays.first else { return }
                            
                            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                            configuration.width = Int(windowInfo.bounds.width * scale)
                            configuration.height = Int(windowInfo.bounds.height * scale)
                        }
                        
                        configuration.showsCursor = false
                        
                        let cgImage = try await SCScreenshotManager.captureImage(
                            contentFilter: filter,
                            configuration: configuration
                        )
                        
                        let image = NSImage(cgImage: cgImage, size: windowInfo.bounds.size)
                        
                        DispatchQueue.main.async {
                            CaptureManager.shared.createNewPinWindow(with: image)
                        }
                    } catch {
                        print("擷取失敗: \(error)")
                    }
                }
            } else {
                print("此功能需要 macOS 13.0 或以上版本")
            }
        }
    }
    
    func getWindowsAsync() async -> [WindowInfo] {
        if #available(macOS 13.0, *) {
            do {
                let cgWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
                var zOrderDict: [CGWindowID: Int] = [:]
                for (index, dict) in cgWindows.enumerated() {
                    if let winId = dict[kCGWindowNumber as String] as? CGWindowID {
                        zOrderDict[winId] = index
                    }
                }
                
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                var windows: [WindowInfo] = []
                
                for window in content.windows {
                    let ownerName = window.owningApplication?.applicationName ?? ""
                    let windowName = window.title ?? ""
                    
                    if ownerName == "Window Server" || ownerName == "Dock" || ownerName == "SystemUIServer" || ownerName == "PinSnap" || ownerName == "Wallpaper" { continue }
                    
                    if window.windowLayer < 0 { continue }
                    
                    let bounds = window.frame
                    if bounds.width < 50 || bounds.height < 50 { continue }
                    
                    windows.append(WindowInfo(
                        windowId: window.windowID,
                        bounds: bounds,
                        ownerName: ownerName,
                        windowName: windowName,
                        layer: Int(window.windowLayer),
                        scWindow: window,
                        zOrder: zOrderDict[window.windowID] ?? 999999
                    ))
                }
                
                windows.sort { $0.zOrder < $1.zOrder }
                
                if let screenFrame = NSScreen.main?.frame {
                    windows.append(WindowInfo(
                        windowId: 0,
                        bounds: screenFrame,
                        ownerName: "Desktop",
                        windowName: "Desktop",
                        layer: -1000,
                        scWindow: nil,
                        zOrder: Int.max
                    ))
                }
                
                return windows
            } catch {
                print("獲取視窗列表失敗: \(error)")
                return []
            }
        } else {
            return []
        }
    }
}

class WindowCaptureOverlayWindow: NSWindow {
    fileprivate let overlayView: WindowCaptureOverlayView
    var onCaptureComplete: ((WindowInfo) -> Void)?
    var onCancel: (() -> Void)?
    
    private var localEventMonitor: Any?
    
    init(screenFrame: CGRect, bgImage: CGImage?) {
        let boundsRect = NSRect(origin: .zero, size: screenFrame.size)
        
        self.overlayView = WindowCaptureOverlayView(frame: boundsRect)
        super.init(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        
        self.level = .screenSaver
        self.isOpaque = true
        self.backgroundColor = .black
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        let container = NSView(frame: boundsRect)
        
        if let cgImage = bgImage {
            let bgView = NSImageView(frame: boundsRect)
            bgView.image = NSImage(cgImage: cgImage, size: boundsRect.size)
            container.addSubview(bgView)
        }
        
        container.addSubview(overlayView)
        self.contentView = container
    }
    
    func startCapture() {
        overlayView.onAreaSelected = { [weak self] windowInfo in
            self?.onCaptureComplete?(windowInfo)
        }
        
        overlayView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onCancel?()
                return nil
            }
            return event
        }
        
        Task { [weak self] in
            let windows = await SmartCaptureManager.shared.getWindowsAsync()
            DispatchQueue.main.async {
                self?.overlayView.cachedWindows = windows
            }
        }
    }
    
    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    override var canBecomeKey: Bool { true }
}

class WindowCaptureOverlayView: NSView {
    private var highlightedWindow: WindowInfo?
    
    private let maskLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let instructionLabel = NSTextField()
    private var trackingArea: NSTrackingArea?
    
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }
    
    var cachedWindows: [WindowInfo] = []
    
    var onAreaSelected: ((WindowInfo) -> Void)?
    var onCancel: (() -> Void)?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupView() {
            wantsLayer = true
            
            maskLayer.frame = bounds
            maskLayer.fillColor = NSColor.black.withAlphaComponent(0.4).cgColor
            maskLayer.fillRule = .evenOdd
            layer?.addSublayer(maskLayer)
            
            highlightLayer.fillColor = NSColor.clear.cgColor
            highlightLayer.strokeColor = NSColor.systemBlue.cgColor
            highlightLayer.lineWidth = 4
            layer?.addSublayer(highlightLayer)
            
            let instructionContainer = NSView()
            instructionContainer.wantsLayer = true
            instructionContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            instructionContainer.layer?.cornerRadius = 18
            instructionContainer.translatesAutoresizingMaskIntoConstraints = false
            addSubview(instructionContainer)
            
            instructionLabel.isBordered = false
            instructionLabel.isEditable = false
            instructionLabel.drawsBackground = false
            instructionLabel.textColor = .white
            instructionLabel.alignment = .center
            instructionLabel.font = .systemFont(ofSize: 15, weight: .bold)
            instructionLabel.stringValue = "Click a window to capture • Press ESC to cancel"
            instructionLabel.translatesAutoresizingMaskIntoConstraints = false
            instructionContainer.addSubview(instructionLabel)
            

            NSLayoutConstraint.activate([
                instructionContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
                instructionContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80),
                instructionContainer.heightAnchor.constraint(equalToConstant: 36),
                
                instructionLabel.centerXAnchor.constraint(equalTo: instructionContainer.centerXAnchor),
                instructionLabel.centerYAnchor.constraint(equalTo: instructionContainer.centerYAnchor),
                
                instructionContainer.widthAnchor.constraint(equalTo: instructionLabel.widthAnchor, constant: 40)
            ])
        }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if let window = highlightedWindow {
            onAreaSelected?(window)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        handleMouseMoved(at: point)
    }
    
    private func handleMouseMoved(at point: CGPoint) {
        var foundWindow: WindowInfo?
        
        for window in cachedWindows {
            if window.bounds.contains(point) {
                foundWindow = window
                break
            }
        }
        
        if highlightedWindow?.windowId != foundWindow?.windowId {
            highlightedWindow = foundWindow
            updateHighlight()
        }
    }
    
    private func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let path = CGMutablePath()
        path.addRect(bounds)
        
        if let window = highlightedWindow {
            path.addRect(window.bounds)
            
            let cornerRadius: CGFloat = 8
            let highlightPath = CGPath(roundedRect: window.bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            highlightLayer.path = highlightPath
            highlightLayer.isHidden = false
        } else {
            highlightLayer.isHidden = true
        }
        
        maskLayer.path = path
        CATransaction.commit()
    }
}
