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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
        checkForUpdates()
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
        // --- 加上版本號碼 (可點擊複製) ---
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let versionItem = NSMenuItem(title: "版本 v\(version)", action: #selector(copyVersion), keyEquivalent: "")
        versionItem.target = self
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
        
        // 顯示複製成功的提示 (使用 Toast 或 Alert)
        let alert = NSAlert()
        alert.messageText = "已複製"
        alert.informativeText = "版本號 v\(version) 已複製到剪貼簿"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "確定")
        alert.runModal()
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
