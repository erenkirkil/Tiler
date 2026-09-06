import Foundation

/// Bir klavye kısayolu. Modifier'lar **Carbon** bayraklarıdır
/// (`cmdKey` 256, `shiftKey` 512, `optionKey` 2048, `controlKey` 4096) çünkü
/// `RegisterEventHotKey` bunları bekler. Cocoa bayraklarıyla (`Cmd` 0x100000)
/// karıştırılmamalıdır — karıştırılırsa maskeler sessizce yanlış yorumlanır.
struct Shortcut: Equatable, Codable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    // Carbon sabitleri, Carbon'u import etmeden kullanılabilsin diye yeniden tanımlı.
    static let cmd: UInt32 = 256
    static let shift: UInt32 = 512
    static let option: UInt32 = 2048
    static let control: UInt32 = 4096

    /// Ayarlar ekranında gösterilecek metin, örn. "⌃⌥⇧←".
    /// Modifier sırası macOS konvansiyonudur: Control, Option, Shift, Command.
    var displayString: String {
        var result = ""
        if carbonModifiers & Shortcut.control != 0 { result += "⌃" }
        if carbonModifiers & Shortcut.option  != 0 { result += "⌥" }
        if carbonModifiers & Shortcut.shift   != 0 { result += "⇧" }
        if carbonModifiers & Shortcut.cmd     != 0 { result += "⌘" }
        return result + Shortcut.keyName(keyCode)
    }

    /// Sanal tuş kodundan görünen ada. Karakter tabanlı eşleme **kullanılmaz**:
    /// karakter klavye düzenine bağlıdır (Türkçe düzende aynı fiziksel tuş farklı
    /// karakter üretir), sanal tuş kodu değildir.
    static func keyName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36:  return "↩"
        case 48:  return "⇥"
        case 49:  return "Boşluk"
        case 53:  return "⎋"
        case 0:   return "A"
        case 1:   return "S"
        case 2:   return "D"
        case 3:   return "F"
        case 4:   return "H"
        case 5:   return "G"
        case 6:   return "Z"
        case 7:   return "X"
        case 8:   return "C"
        case 9:   return "V"
        case 11:  return "B"
        case 12:  return "Q"
        case 13:  return "W"
        case 14:  return "E"
        case 15:  return "R"
        case 16:  return "Y"
        case 17:  return "T"
        case 31:  return "O"
        case 32:  return "U"
        case 34:  return "I"
        case 35:  return "P"
        case 37:  return "L"
        case 38:  return "J"
        case 40:  return "K"
        case 45:  return "N"
        case 46:  return "M"
        default:  return "tuş\(keyCode)"
        }
    }

    /// Varsayılan kısayollar. Tahmin değil ölçüm sonucu: bu makinede yapılan
    /// taramada (131 aktif sistem kısayolu + 247 uygulama menü kısayolu)
    /// Ctrl+Opt+Shift bölgesi 43/43 boştu; Rectangle ve Magnet'in varsayılanı olan
    /// Ctrl+Opt+ok tuşlarının dördü de Android Studio tarafından kullanılıyordu.
    ///
    /// Zihinsel kural: ok tuşları ekran içinde, Cmd eklenince ekranlar arası.
    static let defaults: [WindowAction: Shortcut] = {
        let base = control | option | shift
        let hyper = base | cmd
        return [
            .left:            Shortcut(keyCode: 123, carbonModifiers: base),
            .right:           Shortcut(keyCode: 124, carbonModifiers: base),
            .fill:            Shortcut(keyCode: 126, carbonModifiers: base),
            .center:          Shortcut(keyCode: 125, carbonModifiers: base),
            .fullScreen:      Shortcut(keyCode: 3,   carbonModifiers: base),
            .nextDisplay:     Shortcut(keyCode: 124, carbonModifiers: hyper),
            .previousDisplay: Shortcut(keyCode: 123, carbonModifiers: hyper),
        ]
    }()
}
