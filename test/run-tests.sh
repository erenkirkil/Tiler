#!/bin/bash
# Saf modülleri ve testleri derleyip çalıştırır.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$SRC/test/run"

# Yalnızca saf (AppKit/AX bağımsız) modüller. Yeni saf modül geldikçe buraya eklenir.
PURE=(
  "$SRC/Geometry.swift"
  "$SRC/WindowAction.swift"
  "$SRC/LayoutCalculator.swift"
  "$SRC/ScreenGeometry.swift"
  "$SRC/WindowHistory.swift"
  "$SRC/Shortcut.swift"
  "$SRC/NormalizedShortcut.swift"
)

swiftc -swift-version 6 "${PURE[@]}" "$SRC/test/main.swift" -o "$OUT"
"$OUT"
STATUS=$?
rm -f "$OUT"
exit $STATUS
