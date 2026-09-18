import Cocoa
import ApplicationServices

/// Pencere kimliğini almanın belgelenmiş bir yolu yoktur; `_AXUIElementGetWindow`
/// private bir semboldür. Link zamanında bağlanmak yerine çalışma zamanında çözülür,
/// bulunamazsa hash'ten türetilen yedek kimliğe düşülür.
private typealias AXGetWindowFn =
    @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

private let axGetWindow: AXGetWindowFn? = {
    let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
    guard let handle = dlopen(path, RTLD_NOW),
          let symbol = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
    return unsafeBitCast(symbol, to: AXGetWindowFn.self)
}()

/// Tek bir pencereye Accessibility üzerinden erişim. **Projedeki tüm ham AX çağrıları
/// bu dosyadadır**; başka hiçbir yerde `AXUIElement` ile doğrudan çalışılmaz.
final class AXWindow {

    /// Aynı modüldeki `FullScreenController` bu elemana ihtiyaç duyar.
    let element: AXUIElement
    private let appElement: AXUIElement

    /// AX çağrıları senkron IPC'dir; donmuş bir uygulama sistem varsayılanı boyunca
    /// (birkaç saniye) bloklar. Bu tavan, tek bir donmuş uygulamanın kısayolu
    /// kilitlemesini engeller.
    private static let messagingTimeout: Float = 0.5

    private init?(element: AXUIElement, appElement: AXUIElement) {
        // Her AX elemanı pencere değildir. Örneğin Finder'ın ilk "penceresi"
        // Masaüstü'dür (AXScrollArea) ve tüm ekranları kaplayan sahte bir
        // dikdörtgen döndürür — rol kontrolü olmadan onu taşımaya çalışırız.
        guard AXWindow.stringValue(element, kAXRoleAttribute as String) == kAXWindowRole
        else { return nil }
        self.element = element
        self.appElement = appElement
        AXUIElementSetMessagingTimeout(element, AXWindow.messagingTimeout)
    }

    // MARK: - İzin

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Sistem izin diyaloğunu gösterir. Kullanıcı daha önce reddettiyse diyalog
    /// bir daha çıkmaz; o durumda çağıran taraf Sistem Ayarları'na yönlendirmelidir.
    static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Erişilebilirlik ayarları panelini açar.
    /// Bu URL şeması belgelenmemiştir ve sürümler arasında değişebilir; açılamazsa
    /// Gizlilik ve Güvenlik tercih paneline düşülür.
    static func openAccessibilitySettings() {
        let scheme = "x-apple.systempreferences:com.apple.preference.security"
            + "?Privacy_Accessibility"
        if let url = URL(string: scheme), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }

    // MARK: - Odaktaki pencere

    static func focused() -> AXWindow? {
        guard hasPermission else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }

        return AXWindow(element: raw as! AXUIElement, appElement: appElement)
    }

    // MARK: - Okuma

    var frame: CGRect? {
        guard let origin = pointValue(kAXPositionAttribute as String),
              let size = sizeValue(kAXSizeAttribute as String) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Boyut yazılabilir değilse pencere sabit boyutludur (sistem diyalogları,
    /// bazı yardımcı paneller). Belirlenemiyorsa yeniden boyutlandırılabilir varsayılır.
    var isResizable: Bool {
        var settable: DarwinBoolean = true
        guard AXUIElementIsAttributeSettable(
                element, kAXSizeAttribute as CFString, &settable) == .success
        else { return true }
        return settable.boolValue
    }

    /// Tanılama için: pencerenin ait olduğu uygulamanın bundle kimliği.
    var bundleID: String {
        var pid: pid_t = 0
        guard AXUIElementGetPid(appElement, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid) else { return "?" }
        return app.bundleIdentifier ?? app.localizedName ?? "?"
    }

    var windowID: CGWindowID {
        var id: CGWindowID = 0
        if let fn = axGetWindow, fn(element, &id) == .success, id != 0 { return id }
        // Yedek: gerçek kimlik alınamadığında eleman hash'inden türetilir.
        // Yüksek bit işaretlenir; gerçek pencere kimlikleriyle çakışmaz.
        let hash = UInt32(truncatingIfNeeded: CFHash(element))
        return (hash & 0x7FFF_FFFF) | 0x8000_0000
    }

    // MARK: - Yazma

    /// Pencereyi hedef dikdörtgene taşır ve **gerçekleşen** dikdörtgeni döndürür.
    ///
    /// `kAXErrorSuccess` dönmesi değerin uygulandığını kanıtlamaz — uygulama kendi
    /// min/max boyutuna veya ayrık adımlarına (Terminal'in satır/sütun kilidi) göre
    /// değeri sessizce kırpar. Bu yüzden her yazmadan sonra geri okunup doğrulanır.
    @discardableResult
    func setFrame(_ target: CGRect) -> CGRect? {
        let reEnable = disableEnhancedUserInterfaceIfNeeded()
        defer { if reEnable { setEnhancedUserInterface(true) } }

        for attempt in 0..<3 {
            // Sıra önemli: size -> position -> size. macOS boyutu MEVCUT ekrana
            // sığacak şekilde zorladığı için ekranlar arası taşımada tek geçiş yetmez.
            setSize(target.size)
            setPosition(target.origin)
            setSize(target.size)

            guard let actual = frame else { return nil }
            if AXWindow.matches(actual, target) { return actual }

            if attempt == 2 {
                // privacy: .public şart — os.Logger interpolasyonu varsayılan olarak
                // <private> diye gizler ve tanılama tamamen işe yaramaz hale gelir.
                Log.window.error(
                    "setFrame tutmadı — uygulama=\(self.bundleID, privacy: .public) boyutlandırılabilir=\(self.isResizable, privacy: .public) istenen=\(NSStringFromRect(target), privacy: .public) sonuç=\(NSStringFromRect(actual), privacy: .public)"
                )
                return actual
            }
            usleep(25_000)   // 25 ms — yavaş yanıt veren uygulamalara nefes payı
        }
        return frame
    }

    // MARK: - AXEnhancedUserInterface

    /// VoiceOver bu niteliği öndeki uygulamaya yazar. Chromium, Electron ve Firefox
    /// bunu "ekran okuyucu var" sinyali sayar ve taşımayı animasyonlu, çok yavaş yapar,
    /// üstelik yanlış konumda bitirir. Yazmadan önce kapatılır.
    /// - Returns: Sonradan geri açılması gerekiyorsa `true`.
    private func disableEnhancedUserInterfaceIfNeeded() -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                appElement, "AXEnhancedUserInterface" as CFString, &value) == .success,
              let isOn = value as? Bool, isOn
        else { return false }
        setEnhancedUserInterface(false)
        return true
    }

    private func setEnhancedUserInterface(_ enabled: Bool) {
        AXUIElementSetAttributeValue(
            appElement, "AXEnhancedUserInterface" as CFString, enabled as CFBoolean)
    }

    // MARK: - Düşük seviye yardımcılar

    private func setPosition(_ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    private func pointValue(_ attribute: String) -> CGPoint? {
        guard let raw = copyValue(attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeValue(_ attribute: String) -> CGSize? {
        guard let raw = copyValue(attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func copyValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, attribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        return raw
    }

    private static func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, attribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == CFStringGetTypeID()
        else { return nil }
        return raw as? String
    }

    /// Piksel yuvarlamalarına toleranslı karşılaştırma.
    private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
        let tol: CGFloat = 2
        return abs(a.minX - b.minX) < tol
            && abs(a.minY - b.minY) < tol
            && abs(a.width - b.width) < tol
            && abs(a.height - b.height) < tol
    }
}
