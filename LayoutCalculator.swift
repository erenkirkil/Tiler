import CoreGraphics

/// Hedef dikdörtgeni hesaplar. **Tamamen saftır**: Accessibility'ye, NSScreen'e,
/// zamana veya global duruma hiçbir bağımlılığı yoktur ve yan etkisi yoktur.
/// Bu sayede mantığın tamamı birim testlerle kapatılabilir.
///
/// Koordinat uzayı önemsizdir — verilen `usable` hangi uzaydaysa sonuç da o uzaydadır.
/// Eylemlerin tamamı X ekseninde çalıştığı için Y yönü hiç sorun çıkarmaz.
enum LayoutCalculator {

    /// Genişlik oranları: döngü adımı → kullanılabilir genişliğin kaçta kaçı.
    private static let widthFractions: [CGFloat] = [1.0 / 2.0, 1.0 / 3.0, 2.0 / 3.0]

    /// - Parameters:
    ///   - action: Uygulanacak eylem.
    ///   - usable: Ekranın kullanılabilir alanı (menü çubuğu ve Dock çıkarılmış).
    ///   - step: Döngüdeki sıfır tabanlı adım. `action.cycleLength` ile sınırlanır.
    /// - Returns: Hedef dikdörtgen; eylem bir düzen hesabı gerektirmiyorsa `nil`.
    static func targetRect(action: WindowAction, usable: CGRect, step: Int) -> CGRect? {
        switch action {
        case .fill:
            return usable

        case .left:
            let width = fractionWidth(usable: usable, step: step)
            return CGRect(x: usable.minX, y: usable.minY, width: width, height: usable.height)

        case .right:
            let width = fractionWidth(usable: usable, step: step)
            // Sağ kenara yaslanır; taban alma sonrası solda kalan artık piksel sorun değil.
            return CGRect(x: usable.maxX - width, y: usable.minY,
                          width: width, height: usable.height)

        case .fullScreen, .nextDisplay, .previousDisplay:
            // Bu eylemler düzen hesabı değil; sırasıyla FullScreenController ve
            // AppCoordinator'ın ekran taşıma yolu tarafından ele alınır.
            return nil
        }
    }

    /// Pencereyi bir ekrandan diğerine, kullanılabilir alana göre **oransal** olarak
    /// taşır. Mutlak koordinat taşımak farklı çözünürlükteki ekranlarda pencereyi
    /// ekran dışına atardı.
    static func proportionalRect(frame: CGRect, from: CGRect, to: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return to }

        let relativeX = (frame.minX - from.minX) / from.width
        let relativeY = (frame.minY - from.minY) / from.height
        // Kaynak alandan taşan pencereler hedef alanı da aşmasın.
        let relativeW = min(frame.width / from.width, 1.0)
        let relativeH = min(frame.height / from.height, 1.0)

        return CGRect(x: to.minX + relativeX * to.width,
                      y: to.minY + relativeY * to.height,
                      width: relativeW * to.width,
                      height: relativeH * to.height)
    }

    /// Yeniden boyutlandırılamayan pencereyi hedef bölgede hizalar: bölgeyle paylaşılan
    /// kenara yaslanır, paylaşım yoksa ortalanır. Sol yarım bölgesi ekranın sol kenarını
    /// paylaşır, sağ yarım sağ kenarını; "ekranı doldur" iki kenarı da paylaştığı için
    /// ortalanır. Dikeyde daima ortalanır — bölge zaten tam yükseklik.
    static func fixedSizeRect(size: CGSize, in zone: CGRect,
                              action: WindowAction) -> CGRect {
        let x: CGFloat
        switch action {
        case .left:  x = zone.minX
        case .right: x = zone.maxX - size.width
        default:     x = zone.midX - size.width / 2
        }
        return CGRect(x: x, y: zone.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private static func fractionWidth(usable: CGRect, step: Int) -> CGFloat {
        let index = ((step % widthFractions.count) + widthFractions.count) % widthFractions.count
        return Geometry.floorTolerant(usable.width * widthFractions[index])
    }
}
