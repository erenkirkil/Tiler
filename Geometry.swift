import CoreGraphics

/// Saf geometri yardımcıları. AppKit'e veya Accessibility'ye bağımlı değildir.
enum Geometry {

    /// Ondalık yuvarlama hatasına toleranslı taban alma.
    /// `usable.width / 3` gibi bölmelerde 199.99999 → 200 olmasını sağlar.
    static func floorTolerant(_ value: CGFloat) -> CGFloat {
        floor(value + 0.0001)
    }

    /// İki dikdörtgenin kesişim alanı. Kesişmiyorlarsa 0.
    static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
