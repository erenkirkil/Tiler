import Foundation

/// Kısayolun kaynaktan bağımsız kanonik biçimi.
///
/// Üç kaynak üç farklı modifier kodlaması kullanır ve karıştırılırsa **sessizce**
/// yanlış sonuç verir:
///   - `CopySymbolicHotKeys` → Carbon bayrakları (cmdKey 0x100)
///   - `AppleSymbolicHotKeys` plist → Cocoa bayrakları (Cmd 0x100000)
///   - `kAXMenuItemCmdModifiers` → 5 bitlik kendi şeması, bit3 TERS mantıklı
///
/// Karşılaştırma daima bu tipe indirgenerek yapılır. Karakterle karşılaştırma
/// **asla** yapılmaz: karakter klavye düzenine bağlıdır (Türkçe düzende aynı fiziksel
/// tuş farklı karakter üretir), sanal tuş kodu değildir.
struct NormalizedShortcut: Hashable, Sendable {
    let keyCode: UInt32
    let mask: UInt8

    static let maskShift:    UInt8 = 1 << 0
    static let maskControl:  UInt8 = 1 << 1
    static let maskOption:   UInt8 = 1 << 2
    static let maskCommand:  UInt8 = 1 << 3
    static let maskFunction: UInt8 = 1 << 4

    /// Carbon bayraklarından. `CopySymbolicHotKeys` ve `RegisterEventHotKey` bu
    /// kodlamayı kullanır. 0x20000 biti fn'i temsil ediyor gibi görünüyor;
    /// belgelenmemiştir, bu yüzden yokluğu sorun yaratmaz.
    static func fromCarbon(keyCode: UInt32, carbonModifiers: UInt32) -> NormalizedShortcut {
        var mask: UInt8 = 0
        if carbonModifiers & Shortcut.shift   != 0 { mask |= maskShift }
        if carbonModifiers & Shortcut.control != 0 { mask |= maskControl }
        if carbonModifiers & Shortcut.option  != 0 { mask |= maskOption }
        if carbonModifiers & Shortcut.cmd     != 0 { mask |= maskCommand }
        if carbonModifiers & 0x20000          != 0 { mask |= maskFunction }
        return NormalizedShortcut(keyCode: keyCode, mask: mask)
    }

    /// `kAXMenuItemCmdModifiers` maskesinden.
    ///
    /// DİKKAT: bit3 ters mantıklıdır — bit set **değilse** Command vardır
    /// (`kMenuNoCommandModifier`). Yani `axModifiers == 0`, "modifier yok" değil
    /// "sadece Cmd" demektir. Bu atlanırsa Cmd'li tüm menü kısayolları yanlış çözülür.
    static func fromAXMenu(keyCode: UInt32, axModifiers: Int) -> NormalizedShortcut {
        var mask: UInt8 = 0
        if axModifiers & 1  != 0 { mask |= maskShift }
        if axModifiers & 2  != 0 { mask |= maskOption }
        if axModifiers & 4  != 0 { mask |= maskControl }
        if axModifiers & 8  == 0 { mask |= maskCommand }   // ters mantık
        if axModifiers & 16 != 0 { mask |= maskFunction }
        return NormalizedShortcut(keyCode: keyCode, mask: mask)
    }
}

extension Shortcut {
    var normalized: NormalizedShortcut {
        NormalizedShortcut.fromCarbon(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }
}
