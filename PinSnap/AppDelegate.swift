import Cocoa
import HotKey
import ServiceManagement

struct GitHubRelease: Decodable {
    let tagName: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var snapHotKey: HotKey?
    private var settingsWindowController: SettingsWindowController?
    private var captureMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
        updateMenuTitle() // 恢复保存的快捷键显示
        checkForUpdates()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsDidChange),
            name: .hotkeySettingsChanged,
            object: nil
        )
    }

    func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pin.circle.fill", accessibilityDescription: "Pin Screenshot")
        }
        
        let menu = NSMenu()
        captureMenuItem = NSMenuItem(title: "截圖並釘選", action: #selector(startCapture), keyEquivalent: "P")
        captureMenuItem?.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(captureMenuItem!)
        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        
        // --- 加上開機啟動的選項 ---
        let autostartItem = NSMenuItem(title: "開機自動啟動", action: #selector(toggleAutostart(_:)), keyEquivalent: "")
        // 檢查目前的狀態來決定打勾與否
        autostartItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(autostartItem)
        // -----------------------
        
        menu.addItem(NSMenuItem.separator())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let versionItem = NSMenuItem(title: "版本 v\(version)", action: #selector(copyVersion), keyEquivalent: "")
        versionItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        
        menu.addItem(versionItem)
        // -------------------------------
        
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // 複製版本號碼到剪貼簿
    @objc func copyVersion() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("v\(version)", forType: .string)
        
        CaptureManager.shared.showGlobalToast(message: "Copied to clipboard v\(version) ✓")
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
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupGlobalHotkey() {
        if let hotKey = HotkeySettingsManager.shared.getHotKey() {
            snapHotKey = hotKey
        } else {
            snapHotKey = HotKey(key: .p, modifiers: [.command, .shift])
        }
        snapHotKey?.keyDownHandler = {
            DispatchQueue.main.async { self.startCapture() }
        }
    }

    @objc func hotkeySettingsDidChange() {
        snapHotKey = nil
        setupGlobalHotkey()
        updateMenuTitle()
    }
    
    private func updateMenuTitle() {
        guard let keyCode = HotkeySettingsManager.shared.keyCode,
              let modifiers = HotkeySettingsManager.shared.modifiers else {
            return
        }
        
        let keyName = keyCodeToString(keyCode)
        captureMenuItem?.title = "截圖並釘選"
        
        // 将 keyCode 转换为单个字符作为 keyEquivalent
        let keyChar = keyCodeToKeyEquivalent(keyCode)
        captureMenuItem?.keyEquivalent = keyChar
        captureMenuItem?.keyEquivalentModifierMask = modifiers
    }
    
    private func keyCodeToKeyEquivalent(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "\r",
            37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "n", 46: "m", 47: ".", 48: "\t", 49: " ",
            50: "`", 51: "\u{8}", 53: "\u{1b}"
        ]
        return keyMap[keyCode] ?? ""
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
    
    private func modifiersToString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("Cmd") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        return parts.joined(separator: "+")
    }

    @objc func startCapture() {
        CaptureManager.shared.triggerInteractiveCapture()
    }
    
    // MARK: - 檢查更新
        @objc func checkForUpdates() {
            guard let url = URL(string: "https://api.github.com/repos/Ivantseng123/PinSnap/releases/latest") else { return }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    print("檢查更新失敗: \(error?.localizedDescription ?? "未知錯誤")")
                    return
                }
                
                DispatchQueue.main.async {
                    do {
                        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                        let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        
                        if currentVersion.compare(latestVersion, options: .numeric) == .orderedAscending {
                            self.showUpdateAlert(latestVersion: latestVersion)
                        } else {
                            print("目前已經是最新版本！")
                        }
                    } catch {
                        print("解析更新資訊失敗: \(error)")
                    }
                }
            }
            task.resume()
        }
        
        func showUpdateAlert(latestVersion: String) {
            let alert = NSAlert()
            alert.messageText = "New Version Available"
            alert.informativeText = "PinSnap v\(latestVersion) is now available.\n\nTo update, please run the following command in Terminal:\n\nbrew upgrade --cask pinsnap --no-quarantine"
            alert.alertStyle = .informational

            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Later")
            
            NSApp.activate(ignoringOtherApps: true)
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("brew upgrade --cask pinsnap --no-quarantine", forType: .string)
                print("Update command copied to clipboard ✓")
            }
        }
}
