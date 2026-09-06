import Foundation

/// Kullanıcının tetikleyebileceği altı eylem.
/// Ham değerler `UserDefaults` anahtarı olarak da kullanıldığı için değiştirilmemelidir.
enum WindowAction: String, CaseIterable {
    case left
    case right
    case fill
    case center
    case fullScreen
    case nextDisplay
    case previousDisplay

    /// Aynı kısayola arka arkaya basıldığında kaç farklı boyuta uğranacağı.
    /// 1 olan eylemlerde döngü yoktur.
    var cycleLength: Int {
        switch self {
        case .left, .right:
            return 3    // yarım → 1/3 → 2/3
        case .fill, .center, .fullScreen, .nextDisplay, .previousDisplay:
            return 1
        }
    }

    /// Ayarlar ekranında görünen ad.
    var displayName: String {
        switch self {
        case .left:            return "Sol"
        case .right:           return "Sağ"
        case .fill:            return "Ekranı doldur"
        case .center:          return "Ortala"
        case .fullScreen:      return "Native tam ekran"
        case .nextDisplay:     return "Sonraki ekran"
        case .previousDisplay: return "Önceki ekran"
        }
    }
}
