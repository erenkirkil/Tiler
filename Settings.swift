import Foundation

/// Kısayolların kalıcılığı. `UserDefaults`'a JSON olarak yazılır; ağ, iCloud veya
/// senkron **yoktur** — veri yalnızca bu makinede kalır.
enum Settings {

    private static let prefix = "shortcut."

    /// Kullanıcının atadığı kısayol; hiç değiştirilmediyse varsayılan.
    /// Kullanıcı kısayolu bilinçli olarak sildiyse `nil` döner ve eylem
    /// kısayolsuz kalır.
    static func shortcut(for action: WindowAction) -> Shortcut? {
        let key = prefix + action.rawValue
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return Shortcut.defaults[action]
        }
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    /// `nil` vermek kısayolu kaldırır (varsayılana dönmez).
    static func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) {
        let key = prefix + action.rawValue
        guard let shortcut, let data = try? JSONEncoder().encode(shortcut) else {
            // Boş Data yazmak "kullanıcı bunu bilinçli olarak sildi" demektir;
            // anahtarı tamamen silmek varsayılanı geri getirirdi.
            UserDefaults.standard.set(Data(), forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Tüm kısayolları varsayılana döndürür.
    static func resetAll() {
        for action in WindowAction.allCases {
            UserDefaults.standard.removeObject(forKey: prefix + action.rawValue)
        }
    }
}
