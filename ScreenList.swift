import Cocoa

/// Canlı ekran listesini üretir. AppKit'e bağımlı olduğu için birim testlere girmez;
/// bilinçli olarak ince tutulmuştur — tüm mantık `ScreenGeometry` içindedir.
enum ScreenList {

    /// Bağlı tüm ekranları Quartz uzayında, soldan sağa sıralanmış olarak döndürür.
    static func current() -> [ScreenInfo] {
        let all = NSScreen.screens
        guard let zero = all.first else { return [] }
        let zeroMaxY = zero.frame.maxY

        let infos: [ScreenInfo] = all.compactMap { screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            // visibleFrame menü çubuğunu, Dock'u ve çentik güvenli alanını zaten düşer.
            return ScreenInfo(
                displayID: CGDirectDisplayID(number.uint32Value),
                frame: ScreenGeometry.cocoaToQuartz(screen.frame, zeroMaxY: zeroMaxY),
                usable: ScreenGeometry.cocoaToQuartz(screen.visibleFrame, zeroMaxY: zeroMaxY))
        }
        return ScreenGeometry.ordered(infos)
    }
}
