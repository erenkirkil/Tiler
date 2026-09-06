import CoreGraphics

/// Döngü durumunu tutar: aynı kısayola arka arkaya basıldığında hangi adımın
/// uygulanacağını belirler. **Saftır** — dışarıdan durum okumaz, yalnızca kendi
/// sözlüğünü yönetir; bu sayede tamamen birim testlenebilir.
struct WindowHistory {

    private struct Entry {
        let action: WindowAction
        let step: Int
        /// Bizim en son yazdığımız dikdörtgen. Pencerenin dışarıdan taşınıp
        /// taşınmadığını anlamak için kullanılır.
        let rect: CGRect
    }

    private var entries: [CGWindowID: Entry] = [:]

    /// Bir sonraki döngü adımını hesaplar.
    ///
    /// Şu üç durumda 0'a döner: geçmiş yoksa, son eylem farklıysa veya pencere
    /// Tiler dışında hareket ettiyse. Sonuncusu önemli: kullanıcı pencereyi elle
    /// taşıdıysa döngüyü kaldığı yerden sürdürmek şaşırtıcı olur.
    func nextStep(windowID: CGWindowID, action: WindowAction,
                  currentRect: CGRect) -> Int {
        guard action.cycleLength > 1 else { return 0 }
        guard let last = entries[windowID], last.action == action else { return 0 }
        guard rectsMatch(last.rect, currentRect) else { return 0 }
        return (last.step + 1) % action.cycleLength
    }

    /// Uygulanan eylemi kaydeder. `rect`, AX'ten **geri okunan gerçek** dikdörtgen
    /// olmalıdır — istenen değil. Uygulama pencereyi kırptıysa bir sonraki
    /// karşılaştırma aksi halde daima başarısız olur.
    mutating func record(windowID: CGWindowID, action: WindowAction,
                         step: Int, rect: CGRect) {
        // RAM Optimizasyonu: Zombi pencerelerin (kapatılmış pencereler) hafızada
        // birikmesini önlemek için, kayıt sayısı 100'ü aştığında geçmişi temizle.
        // 100 pencere limiti günlük kullanım için fazlasıyla yeterlidir.
        if entries.count > 100 {
            entries.removeAll(keepingCapacity: false)
        }
        
        entries[windowID] = Entry(action: action, step: step, rect: rect)
    }

    /// Piksel yuvarlamalarına toleranslı karşılaştırma.
    private func rectsMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        let tol: CGFloat = 2
        return abs(a.minX - b.minX) < tol
            && abs(a.minY - b.minY) < tol
            && abs(a.width - b.width) < tol
            && abs(a.height - b.height) < tol
    }
}
