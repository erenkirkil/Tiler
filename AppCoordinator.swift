import Cocoa

/// Kompozisyon kökü ve orkestratör. Tek giriş noktası `execute(_:)`.
/// Kendi başına geometri hesaplamaz, AX çağırmaz — yalnızca sırayı kurar.
final class AppCoordinator {

    private let binder = HotkeyBinder()
    private var history = WindowHistory()
    private var hasPromptedForPermission = false

    /// Ayarlar ekranı bir kısayolu doğrularken buraya o eylem yazılır. Doğrulama
    /// modunda hiçbir eylem ÇALIŞTIRILMAZ; yalnızca tetiklendiği bildirilir —
    /// aksi halde kullanıcı doğrulamak için bastığında penceresi taşınırdı.
    var verifyingAction: WindowAction?

    func start() {
        binder.onTrigger = { [weak self] action in
            self?.handleTrigger(action)
        }
        binder.bindAll()
    }

    /// Kısayollar değiştiğinde yeniden bağlar.
    func rebindShortcuts() {
        binder.bindAll()
    }

    /// Kısayol kaydı sırasında bağlamayı geçici olarak kaldırır.
    func suspendShortcuts() {
        binder.unbindAll()
    }

    private func handleTrigger(_ action: WindowAction) {
        if let verifying = verifyingAction {
            if action == verifying {
                NotificationCenter.default.post(
                    name: .tilerShortcutVerified, object: nil,
                    userInfo: ["action": action.rawValue])
            }
            return
        }
        execute(action)
    }

    func execute(_ action: WindowAction) {
        guard AXWindow.hasPermission else {
            // İlk denemede sistem diyaloğu gösterilir. Kullanıcı reddettiyse diyalog
            // bir daha çıkmaz, bu yüzden sonraki denemelerde panele yönlendirilir.
            if hasPromptedForPermission {
                AXWindow.openAccessibilitySettings()
            } else {
                AXWindow.requestPermission()
                hasPromptedForPermission = true
            }
            return
        }
        guard let window = AXWindow.focused(), let frame = window.frame else { return }

        let screens = ScreenList.current()
        guard let current = ScreenGeometry.screen(containing: frame, in: screens)
        else { return }

        switch action {
        case .fullScreen:
            // Zaten tam ekransa çıkar, değilse girer — geçiş yapar.
            FullScreenController.setFullScreen(
                window, !FullScreenController.isFullScreen(window))

        case .nextDisplay, .previousDisplay:
            let offset = (action == .nextDisplay) ? 1 : -1
            guard let target = ScreenGeometry.neighbor(of: current, offset: offset,
                                                       in: screens) else { return }
            guard exitFullScreenIfNeeded(window) else { return }
            // Pencere tam ekrandan çıktıysa geometri değişmiştir; yeniden oku.
            guard let liveFrame = window.frame else { return }
            let destination = LayoutCalculator.proportionalRect(
                frame: liveFrame, from: current.usable, to: target.usable)
            window.setFrame(destination)
            // Ekran değişti; döngü sayacı bu pencere için anlamını yitirdi.
            history.record(windowID: window.windowID, action: action,
                           step: 0, rect: window.frame ?? destination)

        case .left, .right, .fill:
            guard exitFullScreenIfNeeded(window) else { return }
            guard let liveFrame = window.frame else { return }
            // Tam ekrandan çıkmış olabiliriz; ekranı yeniden tespit et.
            guard let screen = ScreenGeometry.screen(containing: liveFrame, in: screens)
            else { return }

            let step = history.nextStep(windowID: window.windowID, action: action,
                                        currentRect: liveFrame)
            guard let zone = LayoutCalculator.targetRect(
                    action: action, usable: screen.usable, step: step) else { return }

            // Sabit boyutlu pencereler (sistem diyalogları, bazı yardımcı paneller)
            // yeniden boyutlandırılamaz; bölgeyi doldurmak yerine içinde hizalanırlar.
            let target = window.isResizable
                ? zone
                : LayoutCalculator.fixedSizeRect(size: liveFrame.size, in: zone,
                                                 action: action)

            let actual = window.setFrame(target)
            // Kayıt istenen değil GERÇEKLEŞEN dikdörtgenle yapılır; aksi halde
            // pencereyi kırpan uygulamalarda döngü hiç ilerlemez.
            history.record(windowID: window.windowID, action: action,
                           step: step, rect: actual ?? target)
        }
    }

    /// Pencere native tam ekrandaysa çıkarır ve geçişin tamamlanmasını bekler.
    /// - Returns: Devam edilebilirse `true`. Tam ekrandan çıkılamadıysa `false` —
    ///   o durumda taşımaya çalışmak anlamsızdır, pencere kendi Space'inde kilitlidir.
    private func exitFullScreenIfNeeded(_ window: AXWindow) -> Bool {
        guard FullScreenController.isFullScreen(window) else { return true }
        return FullScreenController.setFullScreen(window, false)
    }
}

extension Notification.Name {
    /// Doğrulama modunda kısayolun gerçekten tetiklendiğini bildirir.
    static let tilerShortcutVerified = Notification.Name("tilerShortcutVerified")
}
