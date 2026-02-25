import Cocoa
import VisionKit

// MARK: - 截圖管理器
class CaptureManager {
    static let shared = CaptureManager()
    private var activeControllers: Set<PinnedImageWindowController> = []
    
    func triggerInteractiveCapture() {
        let tempDir = NSTemporaryDirectory()
        let tempFileName = UUID().uuidString + ".png"
        let tempFilePath = URL(fileURLWithPath: tempDir).appendingPathComponent(tempFileName).path
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", tempFilePath]
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if FileManager.default.fileExists(atPath: tempFilePath) {
                    if let image = NSImage(contentsOfFile: tempFilePath) {
                        self?.createNewPinWindow(with: image)
                    }
                    try? FileManager.default.removeItem(atPath: tempFilePath)
                }
            }
        }
        try? task.run()
    }
    
    private func createNewPinWindow(with image: NSImage) {
        let controller = PinnedImageWindowController(image: image)
        activeControllers.insert(controller)
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window, queue: nil) { [weak self] notification in
            if let window = notification.object as? NSWindow,
               let controller = window.windowController as? PinnedImageWindowController {
                self?.activeControllers.remove(controller)
            }
        }
        
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 自訂視窗
class PinnedWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    var onCopyCommand: (() -> Void)?
    
    private var dragStartLocation: NSPoint?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        
        let isCommand = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        if isCommand && event.keyCode == 8 {
            onCopyCommand?()
            return true
        }
        return false
    }
    
    override func sendEvent(_ event: NSEvent) {
        let drawingView = contentView?.subviews.compactMap { $0 as? DrawingOverlayView }.first
        let isDrawing = drawingView?.isDrawingMode == true
        let isTopArea = (contentView?.bounds.height ?? 0) - event.locationInWindow.y <= 30
        
        if event.type == .leftMouseDown {
            let hitView = contentView?.hitTest(event.locationInWindow)
            if hitView is NSControl {
                super.sendEvent(event)
                return
            }
            if isDrawing && !isTopArea {
                super.sendEvent(event)
                return
            }
            dragStartLocation = NSEvent.mouseLocation
        }
        
        if event.type == .leftMouseDragged {
            if dragStartLocation != nil {
                if NSCursor.current == NSCursor.iBeam {
                    super.sendEvent(event)
                    return
                } else {
                    let current = NSEvent.mouseLocation
                    var newOrigin = self.frame.origin
                    newOrigin.x += (current.x - dragStartLocation!.x)
                    newOrigin.y += (current.y - dragStartLocation!.y)
                    self.setFrameOrigin(newOrigin)
                    dragStartLocation = current
                    return
                }
            } else {
                super.sendEvent(event)
                return
            }
        }
        
        if event.type == .leftMouseUp {
            dragStartLocation = nil
        }
        
        super.sendEvent(event)
    }
}

// MARK: - 畫筆塗鴉圖層
class DrawingOverlayView: NSView {
    var isDrawingMode = false
    var strokeColor: NSColor = .systemRed
    var baseSize: CGSize = .init(width: 1, height: 1)
    
    // 💡 修正 1：開放筆跡陣列讓外部讀取，以便合成圖片
    private(set) var strokes: [(path: NSBezierPath, color: NSColor)] = []
    private var currentPath: NSBezierPath?
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isDrawingMode else { return nil }
        if point.y >= self.bounds.height - 30 { return nil }
        return self
    }
    
    private func normalize(_ point: NSPoint) -> NSPoint {
        let scaleX = baseSize.width / max(bounds.width, 1)
        let scaleY = baseSize.height / max(bounds.height, 1)
        return NSPoint(x: point.x * scaleX, y: point.y * scaleY)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isDrawingMode else { return }
        let point = normalize(convert(event.locationInWindow, from: nil))
        currentPath = NSBezierPath()
        currentPath?.lineWidth = 4.0
        currentPath?.lineCapStyle = .round
        currentPath?.lineJoinStyle = .round
        currentPath?.move(to: point)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDrawingMode, let path = currentPath else { return }
        let point = normalize(convert(event.locationInWindow, from: nil))
        path.line(to: point)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDrawingMode, let path = currentPath else { return }
        strokes.append((path: path, color: strokeColor))
        currentPath = nil
        needsDisplay = true
    }
    
    func undoLastStroke() {
        if !strokes.isEmpty {
            strokes.removeLast()
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        let scaleX = bounds.width / max(baseSize.width, 1)
        let scaleY = bounds.height / max(baseSize.height, 1)
        context?.scaleBy(x: scaleX, y: scaleY)
        
        for stroke in strokes {
            stroke.color.setStroke()
            stroke.path.stroke()
        }
        
        if let currentPath = currentPath {
            strokeColor.setStroke()
            currentPath.stroke()
        }
        context?.restoreGState()
    }
    
    // 💡 魔法輔助函數：將目前的筆跡「壓印」到原圖上並輸出成新圖片
    func renderOn(image: NSImage) -> NSImage {
        let result = NSImage(size: image.size)
        result.lockFocus() // 開啟圖片繪圖上下文
        
        // 1. 先畫上原本的截圖底圖
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        
        // 2. 疊加上所有的筆跡 (因為座標已經正規化，所以可以直接畫，不需要縮放)
        for stroke in strokes {
            stroke.color.setStroke()
            stroke.path.stroke()
        }
        
        result.unlockFocus() // 關閉上下文
        return result
    }
}

// MARK: - 浮動視窗控制器 (無敵對比度 UI + 動態 Toast 升級版)
class PinnedImageWindowController: NSWindowController {
    private let imageView = NSImageView()
    private let drawingOverlay = DrawingOverlayView()
    private var pinnedImage: NSImage?
    
    private let controlsContainer = NSView()
    private let opacitySlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let toastContainer = NSView()
    
    private let drawingToolsStack = NSStackView()
    
    private var imageAnalyzer: Any?
    private var imageInteraction: Any?
    
    convenience init(image: NSImage) {
        let window = PinnedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.minSize = NSSize(width: 280, height: 150)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        
        self.init(window: window)
        self.pinnedImage = image
        
        (window as? PinnedWindow)?.onCopyCommand = { [weak self] in
            self?.copyToClipboard()
        }
        
        setupUI(with: image)
        setupLiveTextOCR(with: image)
    }
    
    private func createFloatingButton(symbolName: String, action: Selector, isToggle: Bool = false) -> NSButton {
        let btn = NSButton()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        btn.title = ""
        btn.isBordered = false
        btn.contentTintColor = .white
        
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        btn.layer?.cornerRadius = 14
        btn.layer?.borderWidth = 1.0
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        
        if isToggle { btn.setButtonType(.pushOnPushOff) }
        
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return btn
    }
    
    private func setupUI(with image: NSImage) {
        guard let window = self.window, let contentView = window.contentView else { return }
        
        var rect = window.frame
        rect.size = image.size
        window.setFrame(rect, display: true)
        window.contentAspectRatio = image.size
        drawingOverlay.baseSize = image.size
        
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        contentView.layer?.cornerCurve = .continuous
        
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(imageView)
        
        drawingOverlay.frame = contentView.bounds
        drawingOverlay.autoresizingMask = [.width, .height]
        contentView.addSubview(drawingOverlay)
        
        controlsContainer.frame = contentView.bounds
        controlsContainer.autoresizingMask = [.width, .height]
        controlsContainer.alphaValue = 0.0
        contentView.addSubview(controlsContainer)
        
        let closeBtn = createFloatingButton(symbolName: "xmark", action: #selector(closeWindow))
        controlsContainer.addSubview(closeBtn)
        
        let sliderContainer = NSView()
        sliderContainer.wantsLayer = true
        sliderContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        sliderContainer.layer?.cornerRadius = 14
        sliderContainer.layer?.borderWidth = 1.0
        sliderContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged(_:))
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(opacitySlider)
        controlsContainer.addSubview(sliderContainer)
        
        let copyBtn = createFloatingButton(symbolName: "doc.on.clipboard", action: #selector(copyToClipboard))
        controlsContainer.addSubview(copyBtn)
        
        let penBtn = createFloatingButton(symbolName: "pencil", action: #selector(toggleDrawingMode(_:)), isToggle: true)
        controlsContainer.addSubview(penBtn)
        
        drawingToolsStack.orientation = .horizontal
        drawingToolsStack.spacing = 8
        drawingToolsStack.alignment = .centerY
        drawingToolsStack.translatesAutoresizingMaskIntoConstraints = false
        drawingToolsStack.isHidden = true
        
        let undoBtn = createFloatingButton(symbolName: "arrow.uturn.backward", action: #selector(undoDrawing))
        
        func createColorBtn(color: NSColor, action: Selector) -> NSButton {
            let btn = NSButton()
            btn.wantsLayer = true
            btn.layer?.backgroundColor = color.cgColor
            btn.layer?.cornerRadius = 9
            btn.layer?.borderWidth = 1.5
            btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
            btn.isBordered = false
            btn.title = ""
            btn.target = self
            btn.action = action
            btn.widthAnchor.constraint(equalToConstant: 18).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 18).isActive = true
            return btn
        }
        
        let blackBtn = createColorBtn(color: .black, action: #selector(setColorBlack))
        let redBtn = createColorBtn(color: .systemRed, action: #selector(setColorRed))
        let blueBtn = createColorBtn(color: .systemBlue, action: #selector(setColorBlue))
        let dropperBtn = createFloatingButton(symbolName: "eyedropper", action: #selector(pickColor))
        
        drawingToolsStack.addArrangedSubview(undoBtn)
        drawingToolsStack.addArrangedSubview(blackBtn)
        drawingToolsStack.addArrangedSubview(redBtn)
        drawingToolsStack.addArrangedSubview(blueBtn)
        drawingToolsStack.addArrangedSubview(dropperBtn)
        controlsContainer.addSubview(drawingToolsStack)
        
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 12),
            closeBtn.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 12),
            
            sliderContainer.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 12),
            sliderContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -12),
            sliderContainer.heightAnchor.constraint(equalToConstant: 28),
            sliderContainer.widthAnchor.constraint(equalToConstant: 90),
            
            opacitySlider.centerYAnchor.constraint(equalTo: sliderContainer.centerYAnchor),
            opacitySlider.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor, constant: 10),
            opacitySlider.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor, constant: -10),
            
            copyBtn.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -12),
            copyBtn.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -55),
            
            penBtn.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -12),
            penBtn.trailingAnchor.constraint(equalTo: copyBtn.leadingAnchor, constant: -8),
            
            drawingToolsStack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -12),
            drawingToolsStack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 12),
            drawingToolsStack.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // --- 動態 Toast 提示 ---
        toastContainer.wantsLayer = true
        toastContainer.layer?.cornerRadius = 10
        toastContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        toastContainer.alphaValue = 0.0
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toastContainer)
        
        let toastLabel = NSTextField(labelWithString: "Copied to clipboard ✓")
        toastLabel.font = .systemFont(ofSize: 16, weight: .bold)
        toastLabel.textColor = .white
        toastLabel.isBordered = false
        toastLabel.drawsBackground = false
        toastLabel.alignment = .center
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            toastContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toastContainer.heightAnchor.constraint(equalToConstant: 40),
            
            toastLabel.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor),
            toastLabel.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            
            toastContainer.widthAnchor.constraint(equalTo: toastLabel.widthAnchor, constant: 40)
        ])
        
        let trackingArea = NSTrackingArea(rect: contentView.bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        contentView.addTrackingArea(trackingArea)
        window.center()
    }
    
    private func setupLiveTextOCR(with image: NSImage) {
        if #available(macOS 13.0, *) {
            let analyzer = ImageAnalyzer()
            let overlayView = ImageAnalysisOverlayView()
            overlayView.frame = imageView.bounds
            overlayView.autoresizingMask = [.width, .height]
            overlayView.trackingImageView = imageView
            
            self.window?.contentView?.addSubview(overlayView, positioned: .above, relativeTo: imageView)
            self.imageAnalyzer = analyzer
            self.imageInteraction = overlayView
            
            Task {
                let configuration = ImageAnalyzer.Configuration([.text])
                do {
                    var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                    guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else { return }
                    let analysis = try await analyzer.analyze(cgImage, orientation: .up, configuration: configuration)
                    DispatchQueue.main.async {
                        overlayView.analysis = analysis
                        overlayView.preferredInteractionTypes = .textSelection
                    }
                } catch {
                    print("OCR 辨識失敗: \(error)")
                }
            }
        }
    }
    
    @objc private func toggleDrawingMode(_ sender: NSButton) {
        let isDrawing = sender.state == .on
        drawingOverlay.isDrawingMode = isDrawing
        drawingToolsStack.isHidden = !isDrawing
        sender.layer?.backgroundColor = isDrawing ? NSColor.systemBlue.withAlphaComponent(0.8).cgColor : NSColor.black.withAlphaComponent(0.65).cgColor
    }
    
    @objc private func undoDrawing() { drawingOverlay.undoLastStroke() }
    
    @objc private func setColorBlack() { drawingOverlay.strokeColor = .black }
    @objc private func setColorRed() { drawingOverlay.strokeColor = .systemRed }
    @objc private func setColorBlue() { drawingOverlay.strokeColor = .systemBlue }
    
    @objc private func pickColor() {
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            if let color = selectedColor {
                self?.drawingOverlay.strokeColor = color
            }
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.controlsContainer.animator().alphaValue = 1.0
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.controlsContainer.animator().alphaValue = 0.0
        }
    }
    
    @objc private func closeWindow() { self.close() }
    @objc private func opacityChanged(_ sender: NSSlider) { self.window?.alphaValue = CGFloat(sender.floatValue) }
    
    @objc private func copyToClipboard() {
        guard let image = pinnedImage else { return }
        
        // 💡 修正 1：利用我們剛剛寫好的 renderOn 魔法函數，將畫筆圖層與原圖合而為一！
        let finalImage = drawingOverlay.renderOn(image: image)
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([finalImage])
        showToast(message: "Copied to clipboard ✓")
    }
    
    private func showToast(message: String) {
        if let label = toastContainer.subviews.first as? NSTextField {
            label.stringValue = message
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.toastContainer.animator().alphaValue = 1.0
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    self.toastContainer.animator().alphaValue = 0.0
                }
            }
        }
    }
}
