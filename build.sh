#!/bin/zsh
# Compila, impacchetta, firma e installa Spettro.app
set -e
set -o pipefail   # senza questo un `codesign --verify | tail` maschererebbe un fallimento
cd "$(dirname "$0")"

APP="build/Spettro.app"
# firma: Developer ID se esporti SPETTRO_IDENTITY, altrimenti ad hoc ("-"), che basta per usarla sul proprio Mac
IDENTITY="${SPETTRO_IDENTITY:--}"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ compilo"
# universale: swiftc non accetta due -target, quindi una compilazione per arch + lipo
for a in arm64 x86_64; do
    xcrun swiftc -O -target $a-apple-macos14.2 -o "$APP/Contents/MacOS/Spettro-$a" Sources/*.swift
done
lipo -create "$APP/Contents/MacOS/Spettro-arm64" "$APP/Contents/MacOS/Spettro-x86_64" -output "$APP/Contents/MacOS/Spettro"
rm "$APP/Contents/MacOS/Spettro-arm64" "$APP/Contents/MacOS/Spettro-x86_64"
echo "  archi: $(lipo -archs "$APP/Contents/MacOS/Spettro")"

cp Info.plist "$APP/Contents/Info.plist"

# icona: si rigenera solo se manca (o se si cancella mas/AppIcon.icns)
if [ ! -f mas/AppIcon.icns ]; then
    echo "→ genero l'icona"
    swift mas/make-icon.swift mas/icon-1024.png
    rm -rf mas/AppIcon.iconset && mkdir -p mas/AppIcon.iconset
    for s in 16 32 64 128 256 512; do
        sips -z $s $s mas/icon-1024.png --out mas/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
        sips -z $((s*2)) $((s*2)) mas/icon-1024.png --out mas/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
    done
    cp mas/icon-1024.png mas/AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns mas/AppIcon.iconset -o mas/AppIcon.icns
fi
cp mas/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Localizzazioni: le cartelle <lingua>.lproj in Contents/Resources sono l'unica cosa che rende
# l'app multilingua — niente da dichiarare nell'Info.plist. I .strings si generano da mas/l10n.json.
echo "→ localizzazioni"
if [ mas/l10n.json -nt Resources ] || ! ls Resources/*.lproj >/dev/null 2>&1; then
    python3 mas/l10n.py gen
fi
cp -R Resources/*.lproj "$APP/Contents/Resources/"
echo "  $(ls -d "$APP/Contents/Resources"/*.lproj | wc -l | tr -d ' ') lingue: $(ls -d "$APP/Contents/Resources"/*.lproj | xargs -n1 basename | tr '\n' ' ')"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

echo "→ firmo"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP" 2>&1 | tail -2

echo "→ fatto: $APP"
ls -l "$APP/Contents/MacOS/Spettro"

echo "→ installo in ~/Applications"
rm -rf "$HOME/Applications/Spettro.app" "$HOME/Applications/VUmeter.app"
cp -R "$APP" "$HOME/Applications/"
ls -ld "$HOME/Applications/Spettro.app"
