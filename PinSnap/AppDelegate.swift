import Cocoa
import HotKey
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var snapHotKey: HotKey?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
    }

    func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pin.circle.fill", accessibilityDescription: "Pin Screenshot")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "截圖並釘選 (Cmd+Shift+P)", action: #selector(startCapture), keyEquivalent: "P"))
        menu.addItem(NSMenuItem.separator())
        
        // --- 加上開機啟動的選項 ---
        let autostartItem = NSMenuItem(title: "開機自動啟動", action: #selector(toggleAutostart(_:)), keyEquivalent: "")
        // 檢查目前的狀態來決定打勾與否
        autostartItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(autostartItem)
        // -----------------------
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // 處理開機啟動的邏輯
    @objc func toggleAutostart(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
                print("已取消開機啟動")
            } else {
                try service.register()
                sender.state = .on
                print("已設定開機啟動")
            }
        } catch {
            print("切換開機啟動失敗: \(error)")
        }
    }
    
    func setupGlobalHotkey() {
        snapHotKey = HotKey(key: .p, modifiers: [.command, .shift])
        snapHotKey?.keyDownHandler = {
            DispatchQueue.main.async { self.startCapture() }
        }
    }

    @objc func startCapture() {
        CaptureManager.shared.triggerInteractiveCapture()
    }
}
