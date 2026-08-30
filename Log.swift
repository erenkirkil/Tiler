import os

/// Uygulamanın tek log kanalı.
///
/// `NSLog` **kullanılmaz**: modern macOS'ta çıktısı unified log'a güvenilir şekilde
/// düşmüyor — bu makinede `log show` ile hiç görünmedi, `os.Logger` ise görünüyor.
/// Bir GUI uygulaması `open` ile başlatıldığında stderr hiçbir yere gitmediği için
/// NSLog fiilen sessizdir.
///
/// Okumak için:
///   /usr/bin/log show --last 5m --predicate 'subsystem == "com.erenkirkil.tiler"' --info
///
/// `/usr/bin/log` tam yolla çağrılmalı — zsh'te `log` bir builtin ve onu gölgeliyor.
enum Log {
    private static let subsystem = "com.erenkirkil.tiler"

    /// Pencere taşıma/boyutlandırma tanılaması.
    static let window = Logger(subsystem: subsystem, category: "window")
    /// Kısayol kaydı ve tetiklenmesi.
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    /// Çakışma denetimi.
    static let conflict = Logger(subsystem: subsystem, category: "conflict")
}
