import Cocoa
import ApplicationServices

/// Bir kısayolu kimin sahiplendiği.
enum ConflictOwner: Equatable, Sendable {
    case system
    case app(String)

    var displayName: String {
        switch self {
        case .system:          return "macOS"
        case .app(let name):   return name
        }
    }
}

private typealias CopySymbolicHotKeysFn =
    @convention(c) (UnsafeMutablePointer<Unmanaged<CFArray>?>) -> OSStatus

/// İki katmanlı çakışma denetimi. **Yalnızca ayarlar ekranı açıldığında** çalışır;
/// uygulama normal çalışırken hiç çağrılmaz. Ölçülen süre ~0,5 sn.
enum ConflictOracle {

    /// Katman 1 + katman 2'nin birleşimi.
    /// Arka plan kuyruğunda çağrılmalıdır — AX menü gezintisi bloklayıcıdır.
    static func scan() -> [NormalizedShortcut: [ConflictOwner]] {
        var result: [NormalizedShortcut: [ConflictOwner]] = [:]
        for key in systemShortcuts() {
            result[key, default: []].append(.system)
        }
        for (key, apps) in menuShortcuts() {
            for app in apps.sorted() {
                result[key, default: []].append(.app(app))
            }
        }
        return result
    }

    // MARK: - Katman 1: sistem kısayolları

    /// `CopySymbolicHotKeys` private bir semboldür; link zamanında bağlanmak yerine
    /// çalışma zamanında çözülür. Bulunamazsa denetim sessizce zayıflar ve uygulama
    /// çalışmaya devam eder — private API'ye sert bağımlılık yoktur.
    ///
    /// Not: plist'i (`com.apple.symbolichotkeys`) okumak yeterli **değildir**;
    /// plist yalnızca kullanıcının değiştirdiği girdileri saklar, varsayılanları
    /// içermez. Ölçümde plist 45, bu API 230 kayıt döndürdü.
    private static func systemShortcuts() -> Set<NormalizedShortcut> {
        let path = "/System/Library/Frameworks/Carbon.framework/Carbon"
        guard let handle = dlopen(path, RTLD_NOW),
              let symbol = dlsym(handle, "CopySymbolicHotKeys") else {
            Log.conflict.error("CopySymbolicHotKeys bulunamadı, sistem kısayolu denetimi atlandı")
            return []
        }
        let fn = unsafeBitCast(symbol, to: CopySymbolicHotKeysFn.self)

        var out: Unmanaged<CFArray>?
        guard fn(&out) == noErr,
              let entries = out?.takeRetainedValue() as? [[String: Any]] else { return [] }

        var result = Set<NormalizedShortcut>()
        for entry in entries {
            // Devre dışı kısayollar çakışma sayılmaz; ölçümde 230 kaydın yalnızca
            // 131'i etkindi.
            guard let enabled = entry["kHISymbolicHotKeyEnabled"] as? Int, enabled != 0,
                  let code = entry["kHISymbolicHotKeyCode"] as? Int,
                  let modifiers = entry["kHISymbolicHotKeyModifiers"] as? Int,
                  code != 0xFFFF else { continue }
            result.insert(NormalizedShortcut.fromCarbon(
                keyCode: UInt32(code), carbonModifiers: UInt32(bitPattern: Int32(modifiers))))
        }
        return result
    }

    // MARK: - Katman 2: uygulamaların menü kısayolları

    private static func menuShortcuts() -> [NormalizedShortcut: Set<String>] {
        var result: [NormalizedShortcut: Set<String>] = [:]
        guard AXIsProcessTrusted() else { return result }

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let name = app.localizedName else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            // Yanıt vermeyen bir uygulama tüm taramayı dondurabilir.
            AXUIElementSetMessagingTimeout(element, 0.5)

            var menuBar: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                    element, kAXMenuBarAttribute as CFString, &menuBar) == .success,
                  let raw = menuBar,
                  CFGetTypeID(raw) == AXUIElementGetTypeID() else { continue }

            walk(raw as! AXUIElement, appName: name, depth: 0, into: &result)
        }
        return result
    }

    private static func walk(_ element: AXUIElement, appName: String, depth: Int,
                             into result: inout [NormalizedShortcut: Set<String>]) {
        // Menü ağaçları derin değildir; 9 seviye fazlasıyla yeter ve döngü riskini keser.
        guard depth < 9 else { return }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement] else { return }

        for child in list {
            if let modifiers = intValue(child, kAXMenuItemCmdModifiersAttribute as String),
               let keyCode = menuItemKeyCode(child) {
                let key = NormalizedShortcut.fromAXMenu(keyCode: keyCode,
                                                        axModifiers: modifiers)
                result[key, default: []].insert(appName)
            }
            walk(child, appName: appName, depth: depth + 1, into: &result)
        }
    }

    /// Sanal tuş kodu önceliklidir. `kAXMenuItemCmdChar` yalnızca yedek olarak
    /// kullanılır ve düzene bağlı olduğu için yalnızca ASCII harflerde güvenilirdir;
    /// ok tuşları ve Esc gibi kısayollar zaten `CmdVirtualKey` üzerinden gelir.
    private static func menuItemKeyCode(_ element: AXUIElement) -> UInt32? {
        if let vk = intValue(element, kAXMenuItemCmdVirtualKeyAttribute as String) {
            return UInt32(vk)
        }
        guard let char = stringValue(element, kAXMenuItemCmdCharAttribute as String),
              let scalar = char.lowercased().unicodeScalars.first else { return nil }
        return Self.asciiToKeyCode[Character(scalar)]
    }

    private static let asciiToKeyCode: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    ]

    private static func intValue(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, attribute as CFString, &value) == .success else { return nil }
        return value as? Int
    }

    private static func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
