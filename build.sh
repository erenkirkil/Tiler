#!/bin/bash
# Tiler'ı derler, .app paketine koyar ve Developer ID ile imzalar.
#   ./build.sh          -> yerel imzalı derleme (hardened runtime + timestamp)
#   ./build.sh release  -> + notarization + staple
#
# İmza kimliği sabit kaldığı için Erişilebilirlik izni yeniden derlemelerde korunur.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="$HOME/Applications"
APP="$APPDIR/Tiler.app"

# Kimlik ortam değişkeninden okunur — repoya girmez.
# Kendi kimliğini bul:  security find-identity -v -p codesigning
SIGN_ID="${TILER_SIGN_ID:?TILER_SIGN_ID tanımlı değil — 'security find-identity -v -p codesigning' ile kimliğini bul}"
NOTARY_PROFILE="${TILER_NOTARY_PROFILE:-tiler-notary}"
MODE="${1:-dev}"

echo "== Derleniyor =="
swiftc -O -swift-version 5 "$SRC"/*.swift -o "$SRC/Tiler" \
  -framework Cocoa -framework ApplicationServices -framework Carbon

echo "== .app paketi oluşturuluyor =="
mkdir -p "$APPDIR"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SRC/Tiler" "$APP/Contents/MacOS/Tiler"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$SRC/AppIcon.icns" ]; then
  cp "$SRC/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP/Contents/MacOS/Tiler"

# --options runtime: notarization için zorunlu. --timestamp: güvenli zaman damgası.
echo "== İmzalanıyor =="
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP"

echo "== İmza doğrulanıyor =="
codesign --verify --strict --verbose=2 "$APP"
# Yerel derlemede henüz notarize edilmediği için "rejected" diyebilir; normaldir.
spctl --assess --type execute --verbose=4 "$APP" 2>&1 || true

if [ "$MODE" != "release" ]; then
  echo "OK (yerel imzalı derleme): $APP"
  exit 0
fi

echo "== Notarization =="
ZIP="$SRC/Tiler.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"
spctl --assess --type execute --verbose=4 "$APP"
echo "OK (notarize edilmiş): $APP"
