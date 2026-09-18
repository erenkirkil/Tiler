import CoreGraphics

/// Tek bir ekranın Quartz uzayındaki geometrisi.
/// `usable`, menü çubuğu ve Dock çıkarıldıktan sonra kalan alandır.
struct ScreenInfo: Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let usable: CGRect
}

/// Ekran geometrisinin **saf** kısmı. NSScreen'e ve canlı sisteme bağımlı değildir;
/// tüm fonksiyonlar dışarıdan verilen ekran dizisiyle çalışır ve bu sayede çoklu
/// monitör senaryoları gerçek donanım olmadan test edilebilir.
enum ScreenGeometry {

    /// Cocoa (sol alt orijin, Y yukarı) ile Quartz (sol üst orijin, Y aşağı) arasında
    /// dönüştürür. **Projedeki tek dönüşüm noktasıdır** — başka hiçbir yerde Y çevirmesi
    /// yapılmaz. Fonksiyon kendi tersidir; aynı fonksiyon iki yönde de kullanılır.
    ///
    /// - Parameter zeroMaxY: `NSScreen.screens[0].frame.maxY`. `NSScreen.main`
    ///   **kullanılmaz** — o, odaklanılan pencerenin ekranıdır ve odakla değişir.
    static func cocoaToQuartz(_ rect: CGRect, zeroMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX,
               y: zeroMaxY - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// Ekranları soldan sağa, eşitlikte yukarıdan aşağıya sıralar.
    /// `NSScreen.screens` dizisinin sırası fiziksel dizilişi yansıtmaz; "sonraki ekran"
    /// bu sıralamaya göre hesaplanır.
    static func ordered(_ screens: [ScreenInfo]) -> [ScreenInfo] {
        screens.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.frame.minY < $1.frame.minY
        }
    }

    /// Verilen dikdörtgenin hangi ekranda olduğunu bulur.
    /// Önce tam kapsama aranır, yoksa en büyük kesişim alanı olan ekran seçilir,
    /// hiç kesişim yoksa dizinin ilk ekranına düşülür.
    static func screen(containing rect: CGRect, in screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }
        if let full = screens.first(where: { $0.frame.contains(rect) }) { return full }
        var best: ScreenInfo?
        var bestArea: CGFloat = 0
        for s in screens {
            let area = Geometry.intersectionArea(s.frame, rect)
            if area > bestArea {
                bestArea = area
                best = s
            }
        }
        return best ?? screens.first
    }

    /// Sıralamada `offset` kadar ötedeki ekran. Uçlarda başa/sona sarar.
    /// Tek ekran varsa `nil` döner — taşınacak başka ekran yoktur.
    static func neighbor(of screen: ScreenInfo, offset: Int,
                         in screens: [ScreenInfo]) -> ScreenInfo? {
        guard screens.count > 1,
              let index = screens.firstIndex(where: { $0.displayID == screen.displayID })
        else { return nil }
        let count = screens.count
        let next = ((index + offset) % count + count) % count
        return screens[next]
    }
}
