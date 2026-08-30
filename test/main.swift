import CoreGraphics
import Foundation

// Basit test koşucusu. Harici bağımlılık istemediğimiz için XCTest kullanılmıyor.
var failureCount = 0
var checkCount = 0

func check(_ condition: Bool, _ name: String) {
    checkCount += 1
    if condition {
        print("  ok    \(name)")
    } else {
        print("  HATA  \(name)")
        failureCount += 1
    }
}

func expectRect(_ actual: CGRect, _ expected: CGRect, _ name: String) {
    checkCount += 1
    let tol: CGFloat = 0.5
    let ok = abs(actual.minX - expected.minX) < tol
        && abs(actual.minY - expected.minY) < tol
        && abs(actual.width - expected.width) < tol
        && abs(actual.height - expected.height) < tol
    if ok {
        print("  ok    \(name)")
    } else {
        print("  HATA  \(name)")
        print("        beklenen: \(expected)")
        print("        gelen:    \(actual)")
        failureCount += 1
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    checkCount += 1
    if actual == expected {
        print("  ok    \(name)")
    } else {
        print("  HATA  \(name) — beklenen \(expected), gelen \(actual)")
        failureCount += 1
    }
}

func suite(_ name: String, _ body: () -> Void) {
    print("\n\(name)")
    body()
}

// --- Test paketleri ---

suite("Geometry") {
    check(Geometry.floorTolerant(199.99999) == 200, "floorTolerant yuvarlama hatasını yutar")
    check(Geometry.floorTolerant(200.7) == 200, "floorTolerant normal tabanı alır")
    check(Geometry.intersectionArea(
        CGRect(x: 0, y: 0, width: 10, height: 10),
        CGRect(x: 5, y: 0, width: 10, height: 10)) == 50, "kesişim alanı doğru")
    check(Geometry.intersectionArea(
        CGRect(x: 0, y: 0, width: 10, height: 10),
        CGRect(x: 100, y: 0, width: 10, height: 10)) == 0, "kesişmeyenlerde alan 0")
}

suite("LayoutCalculator") {
    // 1600x1000 kullanılabilir alan, Quartz uzayında (0,0) sol üstte.
    let usable = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    expectRect(LayoutCalculator.targetRect(action: .left, usable: usable, step: 0)!,
               CGRect(x: 0, y: 0, width: 800, height: 1000), "sol adım 0 = sol yarım")
    expectRect(LayoutCalculator.targetRect(action: .left, usable: usable, step: 1)!,
               CGRect(x: 0, y: 0, width: 533, height: 1000), "sol adım 1 = sol 1/3")
    expectRect(LayoutCalculator.targetRect(action: .left, usable: usable, step: 2)!,
               CGRect(x: 0, y: 0, width: 1066, height: 1000), "sol adım 2 = sol 2/3")

    expectRect(LayoutCalculator.targetRect(action: .right, usable: usable, step: 0)!,
               CGRect(x: 800, y: 0, width: 800, height: 1000), "sağ adım 0 = sağ yarım")
    expectRect(LayoutCalculator.targetRect(action: .right, usable: usable, step: 1)!,
               CGRect(x: 1067, y: 0, width: 533, height: 1000), "sağ adım 1 = sağ 1/3")
    expectRect(LayoutCalculator.targetRect(action: .right, usable: usable, step: 2)!,
               CGRect(x: 534, y: 0, width: 1066, height: 1000), "sağ adım 2 = sağ 2/3")

    expectRect(LayoutCalculator.targetRect(action: .fill, usable: usable, step: 0)!,
               usable, "doldur = kullanılabilir alanın tamamı")
    expectRect(LayoutCalculator.targetRect(action: .fill, usable: usable, step: 5)!,
               usable, "doldur adımdan bağımsız")

    // Sağ kenar daima kullanılabilir alanın sağ kenarına yaslanır (boşluk kalmaz).
    let r1 = LayoutCalculator.targetRect(action: .right, usable: usable, step: 1)!
    check(abs(r1.maxX - usable.maxX) < 0.5, "sağ 1/3 sağ kenara yaslı")
    let r2 = LayoutCalculator.targetRect(action: .right, usable: usable, step: 2)!
    check(abs(r2.maxX - usable.maxX) < 0.5, "sağ 2/3 sağ kenara yaslı")

    // Ekranı orijinde olmayan (ikinci monitör) kullanılabilir alan.
    let offset = CGRect(x: 1600, y: 100, width: 1200, height: 800)
    expectRect(LayoutCalculator.targetRect(action: .left, usable: offset, step: 0)!,
               CGRect(x: 1600, y: 100, width: 600, height: 800), "orijin dışı ekranda sol yarım")

    // Düzen eylemi olmayanlar nil döner.
    check(LayoutCalculator.targetRect(action: .fullScreen, usable: usable, step: 0) == nil,
          "fullScreen düzen hesabı üretmez")
    check(LayoutCalculator.targetRect(action: .nextDisplay, usable: usable, step: 0) == nil,
          "nextDisplay düzen hesabı üretmez")

    // Döngü uzunlukları
    expectEqual(WindowAction.left.cycleLength, 3, "sol 3 adımlı döngü")
    expectEqual(WindowAction.fill.cycleLength, 1, "doldur tek adım")
    expectEqual(WindowAction.fullScreen.cycleLength, 1, "tam ekran tek adım")

    // Ekranlar arası taşımada oranlar korunur.
    let small = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let large = CGRect(x: 1000, y: 0, width: 2000, height: 1600)

    let halfOnSmall = CGRect(x: 0, y: 0, width: 500, height: 800)
    expectRect(LayoutCalculator.proportionalRect(frame: halfOnSmall, from: small, to: large),
               CGRect(x: 1000, y: 0, width: 1000, height: 1600),
               "oransal taşıma: sol yarım korunur")

    let centered = CGRect(x: 250, y: 200, width: 500, height: 400)
    expectRect(LayoutCalculator.proportionalRect(frame: centered, from: small, to: large),
               CGRect(x: 1500, y: 400, width: 1000, height: 800),
               "oransal taşıma: ortadaki pencere oranını korur")

    let oversize = CGRect(x: 0, y: 0, width: 1500, height: 1200)
    let clamped = LayoutCalculator.proportionalRect(frame: oversize, from: small, to: large)
    check(clamped.width <= large.width + 0.5 && clamped.height <= large.height + 0.5,
          "oransal taşıma hedef alanı aşmaz")

    // Sabit boyutlu pencereler yeniden boyutlandırılamaz; hedef bölgede hizalanır.
    let zone = CGRect(x: 0, y: 0, width: 800, height: 1000)
    let fixed = CGSize(width: 400, height: 300)
    expectRect(LayoutCalculator.fixedSizeRect(size: fixed, in: zone, action: .left),
               CGRect(x: 0, y: 350, width: 400, height: 300),
               "sabit boyut sola yaslanır")
    expectRect(LayoutCalculator.fixedSizeRect(
                   size: fixed, in: CGRect(x: 800, y: 0, width: 800, height: 1000),
                   action: .right),
               CGRect(x: 1200, y: 350, width: 400, height: 300),
               "sabit boyut sağa yaslanır")
    expectRect(LayoutCalculator.fixedSizeRect(
                   size: fixed, in: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                   action: .fill),
               CGRect(x: 600, y: 350, width: 400, height: 300),
               "sabit boyut doldurmada ortalanır")
    expectRect(LayoutCalculator.fixedSizeRect(
                   size: fixed, in: CGRect(x: 100, y: 50, width: 600, height: 800),
                   action: .left),
               CGRect(x: 100, y: 300, width: 400, height: 300),
               "orijin dışı bölgede sola yaslanır")
}

suite("ScreenGeometry") {
    // Cocoa (sol alt orijin) -> Quartz (sol üst orijin) dönüşümü.
    let zeroMaxY: CGFloat = 1000
    let cocoa = CGRect(x: 10, y: 200, width: 300, height: 400)   // Cocoa: üst kenar y=600
    let quartz = ScreenGeometry.cocoaToQuartz(cocoa, zeroMaxY: zeroMaxY)
    expectRect(quartz, CGRect(x: 10, y: 400, width: 300, height: 400),
               "Cocoa -> Quartz dönüşümü")
    // Dönüşüm kendi tersidir (involution): iki kez uygulamak başa döndürür.
    expectRect(ScreenGeometry.cocoaToQuartz(quartz, zeroMaxY: zeroMaxY), cocoa,
               "dönüşüm involution")

    func mk(_ id: CGDirectDisplayID, _ x: CGFloat, _ y: CGFloat,
            _ w: CGFloat, _ h: CGFloat) -> ScreenInfo {
        let f = CGRect(x: x, y: y, width: w, height: h)
        return ScreenInfo(displayID: id, frame: f, usable: f)
    }

    // Yan yana üç ekran, kasten karışık sırada verildi.
    let a = mk(1, 0, 0, 1000, 800)
    let b = mk(2, 1000, 0, 1200, 900)
    let c = mk(3, -800, 0, 800, 600)
    let mixed = [b, a, c]
    let ordered = ScreenGeometry.ordered(mixed)
    expectEqual(ordered.map { $0.displayID }, [3, 1, 2], "ekranlar soldan sağa sıralanır")

    // Dikey dizilim: X eşit olduğunda üstten alta sıralanır.
    let top = mk(10, 0, 0, 1000, 800)
    let bottom = mk(11, 0, 800, 1000, 800)
    expectEqual(ScreenGeometry.ordered([bottom, top]).map { $0.displayID }, [10, 11],
                "dikey dizilimde üstten alta sıralanır")

    // Hangi ekranda: tam kapsama
    let inA = CGRect(x: 100, y: 100, width: 200, height: 200)
    expectEqual(ScreenGeometry.screen(containing: inA, in: ordered)?.displayID, 1,
                "tamamen içindeyse o ekran")

    // Hangi ekranda: kısmi taşma, en büyük kesişim kazanır
    let straddle = CGRect(x: 900, y: 100, width: 400, height: 200)
    expectEqual(ScreenGeometry.screen(containing: straddle, in: ordered)?.displayID, 2,
                "taşan pencerede en büyük kesişim kazanır")

    // Hangi ekranda: hiç kesişmiyorsa ilk ekran
    let nowhere = CGRect(x: 50000, y: 50000, width: 100, height: 100)
    expectEqual(ScreenGeometry.screen(containing: nowhere, in: ordered)?.displayID, 3,
                "hiç kesişmiyorsa sıralamadaki ilk ekran")

    // Komşu ekran, sona gelince başa sarar
    expectEqual(ScreenGeometry.neighbor(of: a, offset: 1, in: ordered)?.displayID, 2,
                "sonraki ekran")
    expectEqual(ScreenGeometry.neighbor(of: a, offset: -1, in: ordered)?.displayID, 3,
                "önceki ekran")
    expectEqual(ScreenGeometry.neighbor(of: b, offset: 1, in: ordered)?.displayID, 3,
                "son ekrandan sonraki başa sarar")
    expectEqual(ScreenGeometry.neighbor(of: c, offset: -1, in: ordered)?.displayID, 2,
                "ilk ekrandan önceki sona sarar")

    // Tek ekranda komşu yoktur
    check(ScreenGeometry.neighbor(of: a, offset: 1, in: [a]) == nil,
          "tek ekranda komşu nil")
}

suite("WindowHistory") {
    var history = WindowHistory()
    let id: CGWindowID = 42
    let r0 = CGRect(x: 0, y: 0, width: 800, height: 1000)
    let r1 = CGRect(x: 0, y: 0, width: 533, height: 1000)

    // İlk basış daima 0. adım.
    expectEqual(history.nextStep(windowID: id, action: .left, currentRect: .zero), 0,
                "geçmiş yokken ilk adım 0")
    history.record(windowID: id, action: .left, step: 0, rect: r0)

    // Aynı eylem, pencere bizim bıraktığımız yerde: bir sonraki adım.
    expectEqual(history.nextStep(windowID: id, action: .left, currentRect: r0), 1,
                "aynı eylem tekrarında adım ilerler")
    history.record(windowID: id, action: .left, step: 1, rect: r1)
    expectEqual(history.nextStep(windowID: id, action: .left, currentRect: r1), 2,
                "adım ikinci kez ilerler")
    history.record(windowID: id, action: .left, step: 2, rect: r0)

    // Döngü uzunluğu 3 olduğu için başa sarar.
    expectEqual(history.nextStep(windowID: id, action: .left, currentRect: r0), 0,
                "döngü sonunda başa sarar")

    // Farklı eylem sayacı sıfırlar.
    history.record(windowID: id, action: .left, step: 1, rect: r1)
    expectEqual(history.nextStep(windowID: id, action: .right, currentRect: r1), 0,
                "farklı eylemde adım sıfırlanır")

    // Pencere dışarıdan taşındıysa sayaç sıfırlanır.
    history.record(windowID: id, action: .left, step: 1, rect: r1)
    let moved = CGRect(x: 300, y: 300, width: 533, height: 1000)
    expectEqual(history.nextStep(windowID: id, action: .left, currentRect: moved), 0,
                "pencere dışarıdan taşındıysa adım sıfırlanır")

    // Farklı pencereler birbirini etkilemez.
    history.record(windowID: id, action: .left, step: 1, rect: r1)
    expectEqual(history.nextStep(windowID: 99, action: .left, currentRect: .zero), 0,
                "başka pencerenin geçmişi karışmaz")

    // Döngüsü olmayan eylem daima 0 döner.
    history.record(windowID: id, action: .fill, step: 0, rect: r0)
    expectEqual(history.nextStep(windowID: id, action: .fill, currentRect: r0), 0,
                "tek adımlı eylemde adım hep 0")
}

suite("Shortcut") {
    // Carbon modifier sabitleri: cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096
    let ctrlOptShift: UInt32 = 4096 + 2048 + 512
    let left = Shortcut(keyCode: 123, carbonModifiers: ctrlOptShift)
    expectEqual(left.displayString, "\u{2303}\u{2325}\u{21E7}\u{2190}", "Ctrl+Opt+Shift+Sol gösterimi")

    let hyperRight = Shortcut(keyCode: 124, carbonModifiers: ctrlOptShift + 256)
    expectEqual(hyperRight.displayString, "\u{2303}\u{2325}\u{21E7}\u{2318}\u{2192}", "Hyper+Sağ gösterimi")

    let f = Shortcut(keyCode: 3, carbonModifiers: ctrlOptShift)
    expectEqual(f.displayString, "\u{2303}\u{2325}\u{21E7}F", "harf tuşu gösterimi")

    // Her eylemin bir varsayılanı olmalı — eksik kalan varsa kısayolsuz kalır.
    for action in WindowAction.allCases {
        check(Shortcut.defaults[action] != nil, "\(action.rawValue) varsayılanı var")
    }
    expectEqual(Shortcut.defaults.count, WindowAction.allCases.count,
                "varsayılan sayısı eylem sayısına eşit")

    // Varsayılanlar birbiriyle çakışmamalı.
    let unique = Set(Shortcut.defaults.values.map { "\($0.keyCode)-\($0.carbonModifiers)" })
    expectEqual(unique.count, WindowAction.allCases.count,
                "varsayılanlar birbirinden farklı")

    // Ölçüme göre seçilen bölge: eylem 1-4 Ctrl+Opt+Shift, 5-6 buna Cmd ekli.
    expectEqual(Shortcut.defaults[.left]?.carbonModifiers, ctrlOptShift,
                "sol varsayılanı Ctrl+Opt+Shift bölgesinde")
    expectEqual(Shortcut.defaults[.nextDisplay]?.carbonModifiers, ctrlOptShift + 256,
                "sonraki ekran varsayılanı Hyper bölgesinde")

    // Codable turu — UserDefaults'a JSON olarak yazılacak.
    let encoded = try! JSONEncoder().encode(left)
    let decoded = try! JSONDecoder().decode(Shortcut.self, from: encoded)
    expectEqual(decoded, left, "Shortcut kodlama/çözme turu")
}

// --- Sonuç ---

print("\n\(checkCount) kontrol, \(failureCount) hata")
exit(failureCount == 0 ? 0 : 1)
