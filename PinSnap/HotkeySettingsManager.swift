import Foundation
import HotKey

/// Manages hotkey preferences storage using UserDefaults.
/// Thread-safe singleton for storing and retrieving global hotkey configurations.
final class HotkeySettingsManager {
    static let shared = HotkeySettingsManager()
    
    private let keyCodeKey = "hotkey_keyCode"
    private let modifiersKey = "hotkey_modifiers"
    
    /// Sentinel value indicating no hotkey is configured.
    private let noValueSentinel: Int = 0
    
    /// Serial queue for thread-safe UserDefaults access.
    private let queue = DispatchQueue(label: "com.pinsnap.hotkeysettings", qos: .userInitiated)
    
    private init() {}
    
    /// The key code of the configured hotkey.
    /// Returns `nil` if no hotkey is configured.
    var keyCode: Int? {
        get {
            queue.sync {
                let value = UserDefaults.standard.integer(forKey: keyCodeKey)
                return value == noValueSentinel ? nil : value
            }
        }
        set {
            queue.sync {
                UserDefaults.standard.set(newValue ?? noValueSentinel, forKey: keyCodeKey)
            }
        }
    }
    
    /// The modifier flags of the configured hotkey.
    /// Returns `nil` if no hotkey is configured.
    var modifiers: NSEvent.ModifierFlags? {
        get {
            queue.sync {
                let value = UserDefaults.standard.integer(forKey: modifiersKey)
                return value == noValueSentinel ? nil : NSEvent.ModifierFlags(rawValue: UInt(value))
            }
        }
        set {
            queue.sync {
                UserDefaults.standard.set(newValue?.rawValue ?? noValueSentinel, forKey: modifiersKey)
            }
        }
    }
    
    /// Saves the hotkey configuration.
    /// - Parameters:
    ///   - keyCode: The key item representing the hotkey key, or `nil` to clear.
    ///   - modifiers: The modifier flags for the hotkey.
    func save(keyCode: KeyItem?, modifiers: NSEvent.ModifierFlags) {
        guard let keyCode = keyCode else {
            self.keyCode = nil
            self.modifiers = nil
            return
        }
        
        let keyCodeValue = Int(keyCode.rawValue)
        guard keyCodeValue > 0 && keyCodeValue <= 127 else {
            return
        }
        
        self.keyCode = keyCodeValue
        self.modifiers = modifiers
    }
    
    /// Retrieves the configured hotkey.
    /// - Returns: A `HotKey` instance if configured, `nil` otherwise.
    func getHotKey() -> HotKey? {
        guard let keyCode = keyCode, let modifiers = modifiers else {
            return nil
        }
        return HotKey(keyCode: keyCode, modifiers: modifiers)
    }
}
