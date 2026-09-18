import Carbon
import Cocoa

/// Carbon `RegisterEventHotKey` üzerine ince sarmalayıcı.
///
/// Neden Carbon: CGEventTap'in aksine ek TCC izni istemez, Secure Event Input
/// etkinken (bir parola alanı odaktayken) bloke olmaz ve kendiliğinden devre dışı
/// kalmaz. Bedeli olayı yutamamaktır — bizim ihtiyacımız olmayan bir yetenek.
///
/// ÖNEMLİ: `RegisterEventHotKey`'in `noErr` dönmesi kısayolun **çalışacağını
/// kanıtlamaz**. Sistemin sahiplendiği kombinasyonlar da başarıyla "kaydedilir"
/// ama handler hiç tetiklenmez. Doğrulama, kullanıcıya bir kez bastırmakla yapılır.
final class HotkeyBinder {

    /// Carbon geri çağrısı C fonksiyon işaretçisidir ve bağlam yakalayamaz;
    /// tek örnek bu global üzerinden bulunur.
    nonisolated(unsafe) fileprivate static var shared: HotkeyBinder?

    /// 'TILR' — bu uygulamanın kısayol imzası.
    private static let signature: OSType = 0x54_49_4C_52

    private var handlerRef: EventHandlerRef?
    private var refs: [WindowAction: EventHotKeyRef] = [:]
    private var actionsByID: [UInt32: WindowAction] = [:]
    private var nextID: UInt32 = 1

    /// Kısayol tetiklendiğinde çağrılır. Ana kuyrukta çalışır.
    var onTrigger: ((WindowAction) -> Void)?

    init() {
        HotkeyBinder.shared = self
        installHandler()
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID)
            guard status == noErr,
                  let binder = HotkeyBinder.shared,
                  let action = binder.actionsByID[hotKeyID.id]
            else { return OSStatus(eventNotHandledErr) }
            binder.onTrigger?(action)
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    /// Ayarlardaki tüm kısayolları kaydeder. Önce mevcutları çözer, böylece
    /// kullanıcı bir kısayolu değiştirdiğinde eskisi tetiklenmeye devam etmez.
    func bindAll() {
        unbindAll()
        for action in WindowAction.allCases {
            guard let shortcut = Settings.shortcut(for: action) else { continue }
            bind(shortcut, to: action)
        }
    }

    func unbindAll() {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actionsByID.removeAll()
    }

    private func bind(_ shortcut: Shortcut, to action: WindowAction) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotkeyBinder.signature, id: id)
        let status = RegisterEventHotKey(shortcut.keyCode,
                                         shortcut.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let ref else {
            Log.hotkey.error("\(action.rawValue) kısayolu kaydedilemedi (durum \(status))")
            return
        }
        refs[action] = ref
        actionsByID[id] = action
    }

    deinit { unbindAll() }
}
