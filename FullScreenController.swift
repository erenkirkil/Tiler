import Cocoa
import ApplicationServices

/// Native tam ekran (yeşil düğme davranışı): pencere kendi Space'ine taşınır,
/// menü çubuğu ve Dock gizlenir. "Ekranı doldur" eyleminden farklıdır.
enum FullScreenController {

    /// Space animasyonunun tamamlanması için beklenecek üst sınır.
    private static let transitionTimeout: TimeInterval = 1.0
    private static let pollInterval: useconds_t = 50_000   // 50 ms

    static func isFullScreen(_ window: AXWindow) -> Bool {
        var value: CFTypeRef?
        // CFBoolean Swift'te Bool'a köprülenir; zorlamalı çevrim derleyici uyarısı üretir.
        guard AXUIElementCopyAttributeValue(
                window.element, "AXFullScreen" as CFString, &value) == .success,
              let isOn = value as? Bool
        else { return false }
        return isOn
    }

    /// Tam ekranı açar veya kapatır ve geçişin **gerçekten** tamamlanmasını bekler.
    ///
    /// Yazma başarılı dönse bile nitelik geri okunarak doğrulanır; Space animasyonu
    /// bitmeden dönersek çağıran taraf hâlâ eski Space'teki geometriyle çalışır.
    @discardableResult
    static func setFullScreen(_ window: AXWindow, _ enabled: Bool) -> Bool {
        if isFullScreen(window) == enabled { return true }

        let status = AXUIElementSetAttributeValue(
            window.element, "AXFullScreen" as CFString, enabled as CFBoolean)

        if status != .success {
            // AXFullScreen'i desteklemeyen uygulamalar için yedek yol:
            // tam ekran düğmesine bas. Düğme de yoksa yapacak bir şey kalmaz.
            guard pressFullScreenButton(window) else { return false }
        }

        return waitForTransition(window, to: enabled)
    }

    private static func pressFullScreenButton(_ window: AXWindow) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                window.element, kAXFullScreenButtonAttribute as CFString,
                &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return false }
        return AXUIElementPerformAction(
            raw as! AXUIElement, kAXPressAction as CFString) == .success
    }

    private static func waitForTransition(_ window: AXWindow, to expected: Bool) -> Bool {
        let deadline = Date().addingTimeInterval(transitionTimeout)
        while Date() < deadline {
            if isFullScreen(window) == expected { return true }
            usleep(pollInterval)
        }
        return false
    }
}
