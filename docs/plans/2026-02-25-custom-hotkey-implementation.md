# 自訂快捷鍵設定 - 實作計畫

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目標：** 在 PinSnap 選單列 App 中新增設定視窗，讓使用者能自訂截圖快捷鍵

**架構：** 在 AppDelegate 中新增設定選單和設定視窗，使用 UserDefaults 儲存快捷鍵設定，利用 HotKey 庫監聽自訂快捷鍵

**技術堆疊：** Swift, Cocoa, HotKey 庫, UserDefaults

---

## Task 1: 建立 HotkeySettingsManager

**Files:**
- Create: `PinSnap/HotkeySettingsManager.swift`

**Step 1: 建立儲存管理類別**

```swift
import Foundation
import HotKey

class HotkeySettingsManager {
    static let shared = HotkeySettingsManager()
    
    private let keyCodeKey = "hotkey_keyCode"
    private let modifiersKey = "hotkey_modifiers"
    
    private init() {}
    
    var keyCode: Int? {
        get {
            let value = UserDefaults.standard.integer(forKey: keyCodeKey)
            return value == 0 ? nil : value
        }
        set {
            UserDefaults.standard.set(newValue ?? 0, forKey: keyCodeKey)
        }
    }
    
    var modifiers: NSEvent.ModifierFlags? {
        get {
            let value = UserDefaults.standard.integer(forKey: modifiersKey)
            return value == 0 ? nil : NSEvent.ModifierFlags(rawValue: UInt(value))
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue ?? 0, forKey: modifiersKey)
        }
    }
    
    func save(keyCode: KeyItem?, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode?.rawValue
        self.modifiers = modifiers
    }
    
    func getHotKey() -> HotKey? {
        guard let keyCode = keyCode, let modifiers = modifiers else {
            return nil
        }
        return HotKey(keyCode: keyCode, modifiers: modifiers)
    }
}
```

**Step 2: 提交**

```bash
git add PinSnap/HotkeySettingsManager.swift
git commit -m "feat: add HotkeySettingsManager for storing hotkey preferences"
```

---

## Task 2: 修改 AppDelegate - 新增設定選單

**Files:**
- Modify: `PinSnap/AppDelegate.swift`

**Step 1: 新增設定選單項目**

在 `setupMenu()` 函數中，在「截圖並釘選」項目後新增：

```swift
// 在 menu.addItem(NSMenuItem.separator()) 之前加入
menu.addItem(NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ","))
```

**Step 2: 新增 openSettings 方法**

在 `toggleAutostart` 方法後新增：

```swift
@objc func openSettings() {
    let settingsWindow = SettingsWindowController()
    settingsWindow.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Step 3: 修改 setupGlobalHotkey 使用儲存的設定**

```swift
func setupGlobalHotkey() {
    if let hotKey = HotkeySettingsManager.shared.getHotKey() {
        snapHotKey = hotKey
    } else {
        // 預設快捷鍵
        snapHotKey = HotKey(key: .p, modifiers: [.command, .shift])
    }
    snapHotKey?.keyDownHandler = {
        DispatchQueue.main.async { self.startCapture() }
    }
}
```

**Step 4: 提交**

```bash
git add PinSnap/AppDelegate.swift
git commit -m "feat: add settings menu and load custom hotkey"
```

---

## Task 3: 建立設定視窗

**Files:**
- Create: `PinSnap/SettingsWindowController.swift`

**Step 1: 建立視窗控制器**

```swift
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
```

**Step 2: 提交**

```bash
git add PinSnap/SettingsWindowController.swift
git commit -m "feat: add SettingsWindowController"
```

---

## Task 4: 建立設定視圖控制器

**Files:**
- Create: `PinSnap/SettingsViewController.swift`

**Step 1: 建立 ViewController**

```swift
import Cocoa

class SettingsViewController: NSViewController {
    
    private var hotkeyField: NSTextField!
    private var recordButton: NSButton!
    private var isRecording = false
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateHotkeyDisplay()
    }
    
    private func setupUI() {
        // 標題
        let titleLabel = NSTextField(labelWithString: "截圖快捷鍵")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: 150, width: 100, height: 20)
        view.addSubview(titleLabel)
        
        // 快捷鍵顯示欄位
        hotkeyField = NSTextField(frame: NSRect(x: 20, y: 110, width: 250, height: 30))
        hotkeyField.isEditable = false
        hotkeyField.isSelectable = false
        hotkeyField.alignment = .center
        hotkeyField.font = NSFont.systemFont(ofSize: 14)
        hotkeyField.wantsLayer = true
        hotkeyField.layer?.borderWidth = 1
        hotkeyField.layer?.cornerRadius = 5
        view.addSubview(hotkeyField)
        
        // 錄製按鈕
        recordButton = NSButton(title: "錄製", target: self, action: #selector(startRecording))
        recordButton.frame = NSRect(x: 280, y: 110, width: 80, height: 30)
        view.addSubview(recordButton)
        
        // 儲存按鈕
        let saveButton = NSButton(title: "儲存", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 200, y: 20, width: 80, height: 30)
        saveButton.bezelStyle = .rounded
        view.addSubview(saveButton)
        
        // 取消按鈕
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelSettings))
        cancelButton.frame = NSRect(x: 290, y: 20, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        view.addSubview(cancelButton)
        
        // 設定預設快捷鍵
        if HotkeySettingsManager.shared.keyCode == nil {
            HotkeySettingsManager.shared.keyCode = 35  // Key.p
            HotkeySettingsManager.shared.modifiers = [.command, .shift]
        }
    }
    
    private func updateHotkeyDisplay() {
        if let keyCode = HotkeySettingsManager.shared.keyCode,
           let modifiers = HotkeySettingsManager.shared.modifiers {
            let keyName = keyCodeToString(keyCode)
            let modString = modifiersToString(modifiers)
            hotkeyField.stringValue = "\(modString) + \(keyName)"
        } else {
            hotkeyField.stringValue = "Cmd + Shift + P"
        }
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
        return parts.joined(separator: " + ")
    }
    
    @objc private func startRecording() {
        isRecording = true
        recordButton.title = "按下快捷鍵..."
        hotkeyField.stringValue = "..."
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            if event.keyCode == 53 { // Escape
                self.isRecording = false
                self.recordButton.title = "錄製"
                self.updateHotkeyDisplay()
                return nil
            }
            
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return event } // 至少需要一個修飾鍵
            
            self.currentKeyCode = event.keyCode
            self.currentModifiers = modifiers
            
            self.isRecording = false
            self.recordButton.title = "錄製"
            self.updateHotkeyDisplay()
            
            return nil
        }
    }
    
    private var currentKeyCode: Int?
    private var currentModifiers: NSEvent.ModifierFlags?
    
    @objc private func saveSettings() {
        if let keyCode = currentKeyCode, let modifiers = currentModifiers {
            HotkeySettingsManager.shared.save(
                keyCode: KeyItem(carbonKeyCode: UInt32(keyCode)),
                modifiers: modifiers
            )
        }
        
        // 重新註冊快捷鍵
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        
        view.window?.close()
    }
    
    @objc private func cancelSettings() {
        view.window?.close()
    }
}

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}
```

**Step 2: 提交**

```bash
git add PinSnap/SettingsViewController.swift
git commit -m "feat: add SettingsViewController with hotkey recording"
```

---

## Task 5: 修改 AppDelegate 監聽設定變更

**Files:**
- Modify: `PinSnap/AppDelegate.swift`

**Step 1: 新增 Notification 觀察者**

在 `applicationDidFinishLaunching` 中新增：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(hotkeySettingsDidChange),
    name: .hotkeySettingsChanged,
    object: nil
)
```

**Step 2: 新增處理方法**

```swift
@objc func hotkeySettingsDidChange() {
    snapHotKey = nil
    setupGlobalHotkey()
}
```

**Step 3: 提交**

```bash
git add PinSnap/AppDelegate.swift
git commit -m "feat: reload hotkey when settings change"
```

---

## Task 6: 驗證功能

**Step 1: 使用 Xcode 開啟專案**

```bash
open PinSnap.xcodeproj
```

**Step 2: 編譯並執行**

在 Xcode 中執行 App，確認：
1. 選單列出現「設定...」選項
2. 點擊後開啟設定視窗
3. 顯示目前快捷鍵 Cmd + Shift + P
4. 點擊錄製，按下新快捷鍵（如 Cmd + Shift + X）
5. 儲存後，新快捷鍵生效

**Step 3: 提交**

```bash
git add .
git commit -m "feat: implement custom hotkey settings feature"
```

---

## 預期結果

- [x] 選單列有「設定...」選項
- [x] 設定視窗可開啟
- [x] 可錄製新快捷鍵
- [x] 儲存後快捷鍵立即生效
- [x] 重啟 App 後設定持續
