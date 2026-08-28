# Tiler

Klavye kısayollarıyla pencere yerleştiren macOS menü-çubuğu uygulaması. Kısayollar her
zaman **odaktaki pencereye** uygulanır ve hesaplama o pencerenin bulunduğu **ekranın**
kullanılabilir alanına göre yapılır — dahili ekran da harici monitör de aynı şekilde
çalışır.

**İnternete hiç bağlanmaz.** Ağ çağrısı yapan hiçbir kod ve hiçbir üçüncü parti bağımlılık
yoktur; otomatik güncelleyici (Sparkle) bilinçli olarak kullanılmaz.

## Eylemler

Aynı kısayola arka arkaya basmak bir sonraki boyuta geçer, son adımdan sonra başa döner.

| Eylem | Davranış | Varsayılan kısayol |
|---|---|---|
| Sol | sol yarım → sol 1/3 → sol 2/3 | `Ctrl+Opt+Shift+←` |
| Sağ | sağ yarım → sağ 1/3 → sağ 2/3 | `Ctrl+Opt+Shift+→` |
| Ekranı doldur | kullanılabilir alana yay | `Ctrl+Opt+Shift+↑` |
| Native tam ekran | yeşil düğme davranışı, ayrı Space | `Ctrl+Opt+Shift+F` |
| Sonraki ekran | pencereyi bir sonraki monitöre taşı | `Ctrl+Opt+Shift+Cmd+→` |
| Önceki ekran | pencereyi bir önceki monitöre taşı | `Ctrl+Opt+Shift+Cmd+←` |

Zihinsel kural: **ok tuşları ekran içinde, Hyper+ok ekranlar arası.** Tüm kısayollar
ayarlar ekranından değiştirilebilir.

## Neden bu varsayılanlar

Varsayılanlar tahmin değil ölçüm sonucu. Bu makinede yapılan taramada (131 aktif sistem
kısayolu + 247 uygulama menü kısayolu) Rectangle ve Magnet'in varsayılanı olan
`Ctrl+Opt+ok tuşları` bölgesinde **dört ok tuşunun dördü de** Android Studio tarafından
kullanılıyordu. `Ctrl+Opt+Shift` bölgesi ise 43/43 boştu.

## Çakışma denetimi

Kısayol ayarları ekranı açıldığında iki katmanlı bir denetim çalışır (~0,5 sn, yalnızca
o an): sistem kısayolları (`CopySymbolicHotKeys`) ve çalışan uygulamaların menü
kısayolları (Accessibility ile menü çubuğu taraması). Çakışma, sahibinin adıyla
gösterilir: "Android Studio bunu kullanıyor".

Kapatılamayan kör nokta: başka uygulamaların kaydettiği **global** kısayolları (Raycast,
Alfred, CleanShot X) numaralandıran hiçbir API yok. Bu, kullanıcıya açıkça söylenir.

## Kapsam dışı

Yatay (üst/alt) bölme, köşe döşemesi, geri al, pencere değiştirici, sürükle-yapıştır,
gap ayarları, Stage Manager desteği. Kapsam kasıtlı olarak dar.

## İzinler

Erişilebilirlik (Accessibility) izni gerekir — başka uygulamaların pencerelerini taşımanın
tek yolu budur. App Sandbox kullanılamaz (Apple erişilebilirlik API'lerini sandbox içinde
yasaklıyor), dolayısıyla Mac App Store yolu kapalıdır; dağıtım Developer ID imzası ve
notarization ile doğrudan yapılır.
