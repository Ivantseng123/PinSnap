import Cocoa

class SettingsWindowController: NSWindowController {
    
    convenience init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "PinSnap 設定"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 200))
        window.center()
        
        self.init(window: window)
    }
}
