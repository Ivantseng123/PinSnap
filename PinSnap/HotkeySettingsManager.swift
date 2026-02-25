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
