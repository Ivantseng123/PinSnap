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
            // 這是你專案的 GitHub Latest Release API 網址
            guard let url = URL(string: "https://api.github.com/repos/Ivantseng123/PinSnap/releases/latest") else { return }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    print("檢查更新失敗: \(error?.localizedDescription ?? "未知錯誤")")
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    // 將抓到的 "v1.1.0" 去掉 "v"，變成 "1.1.0"
                    let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                    
                    // 取得目前 App 的版本號 (讀取 Xcode 裡的 Version)
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                    
                    // 比對版本號：如果目前版本比最新版本舊
                    if currentVersion.compare(latestVersion, options: .numeric) == .orderedAscending {
                        DispatchQueue.main.async {
                            self.showUpdateAlert(latestVersion: latestVersion)
                        }
                    } else {
                        print("目前已經是最新版本！")
                    }
                } catch {
                    print("解析更新資訊失敗: \(error)")
                }
            }
            task.resume()
        }
        
        func showUpdateAlert(latestVersion: String) {
            let alert = NSAlert()
            alert.messageText = "發現新版本！"
            alert.informativeText = "PinSnap 已經推出 v\(latestVersion) 囉！\n\n請打開終端機 (Terminal) 輸入以下指令來更新：\n\nbrew upgrade --cask pinsnap --no-quarantine"
            alert.alertStyle = .informational
            
            alert.addButton(withTitle: "我知道了")
            let copyButton = alert.addButton(withTitle: "複製更新指令")
            
            // 讓視窗浮在最上層
            NSApp.activate(ignoringOtherApps: true)
            
            let response = alert.runModal()
            // 如果使用者點擊了第二個按鈕 (複製更新指令)
            if response == .alertSecondButtonReturn {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("brew upgrade --cask pinsnap --no-quarantine", forType: .string)
                print("更新指令已複製到剪貼簿")
            }
        }
}
