import Cocoa
import HotKey

class SettingsViewController: NSViewController {
    
    private var hotkeyField: NSTextField!
    private var recordButton: NSButton!
    private var isRecording = false
    private var eventMonitor: Any?
    
    // Key code 35 corresponds to the 'P' key
    private let defaultKeyCode: Int = 35
    
    private var currentKeyCode: Int?
    private var currentModifiers: NSEvent.ModifierFlags?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateHotkeyDisplay()
    }
    
    private func setupUI() {
        let titleLabel = NSTextField(labelWithString: "截圖快捷鍵")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: 150, width: 100, height: 20)
        view.addSubview(titleLabel)
        
        hotkeyField = NSTextField(frame: NSRect(x: 20, y: 110, width: 250, height: 30))
        hotkeyField.isEditable = false
        hotkeyField.isSelectable = false
        hotkeyField.alignment = .center
        hotkeyField.font = NSFont.systemFont(ofSize: 14)
        hotkeyField.wantsLayer = true
        hotkeyField.layer?.borderWidth = 1
        hotkeyField.layer?.cornerRadius = 5
        view.addSubview(hotkeyField)
        
        recordButton = NSButton(title: "錄製", target: self, action: #selector(startRecording))
        recordButton.frame = NSRect(x: 280, y: 110, width: 80, height: 30)
        view.addSubview(recordButton)
        
        let saveButton = NSButton(title: "儲存", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 200, y: 20, width: 80, height: 30)
        saveButton.bezelStyle = .rounded
        view.addSubview(saveButton)
        
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelSettings))
        cancelButton.frame = NSRect(x: 290, y: 20, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        view.addSubview(cancelButton)
    }
    
    private func updateHotkeyDisplay() {
        guard let hotkeyField = hotkeyField else { return }
        
        if let keyCode = HotkeySettingsManager.shared.keyCode,
           let modifiers = HotkeySettingsManager.shared.modifiers {
            let keyName = keyCodeToString(keyCode)
            let modString = modifiersToString(modifiers)
            hotkeyField.stringValue = "\(modString) + \(keyName)"
        } else {
            let keyName = keyCodeToString(defaultKeyCode)
            hotkeyField.stringValue = "Cmd + Shift + \(keyName)"
        }
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        // Reference: https://github.com/soffes/HotKey/blob/main/HotKey/KeyTypes.swift
        // Common key codes: 35 = P, 53 = Escape, 36 = Return
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
        recordButton.title = NSLocalizedString("按下快捷鍵...", comment: "Recording prompt")
        hotkeyField.stringValue = "..."
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            // 53 = Escape key
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return event }
            
            self.currentKeyCode = event.keyCode
            self.currentModifiers = modifiers
            
            self.stopRecording()
            self.updateHotkeyDisplay()
            
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordButton.title = NSLocalizedString("錄製", comment: "Record button")
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    @objc private func saveSettings() {
        if let keyCode = currentKeyCode, let modifiers = currentModifiers {
            HotkeySettingsManager.shared.save(
                keyCode: KeyItem(carbonKeyCode: UInt32(keyCode)),
                modifiers: modifiers
            )
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
            view.window?.close()
        } else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("未設定快捷鍵", comment: "Alert title")
            alert.informativeText = NSLocalizedString("請先錄製新的快捷鍵，或點擊取消關閉視窗。", comment: "Alert message")
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("確定", comment: "OK button"))
            alert.runModal()
        }
    }
    
    @objc private func cancelSettings() {
        stopRecording()
        currentKeyCode = nil
        currentModifiers = nil
        view.window?.close()
    }
}

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}
