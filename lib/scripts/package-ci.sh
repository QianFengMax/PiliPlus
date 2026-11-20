#!/usr/bin/env bash
# 打包 arm64 deb
set -euo pipefail
WS="$PWD"
ARCH="$(dpkg --print-architecture)"
VERSION=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
BUNDLE="build/linux/arm64/release/bundle"
[ -d "$BUNDLE" ] || BUNDLE="build/linux/x64/release/bundle"
[ -d "$BUNDLE" ] || { echo "bundle not found"; exit 1; }

PKG="PiliPlus_linux_${VERSION}_${ARCH}"
rm -rf "$PKG"
mkdir -p "$PKG/opt/PiliPlus" "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/512x512/apps" "$PKG/DEBIAN"

cp -r "$BUNDLE"/* "$PKG/opt/PiliPlus/"
cp assets/linux/DEBIAN/control "$PKG/DEBIAN/control"
cp assets/linux/com.example.piliplus.desktop "$PKG/usr/share/applications/"
cp assets/images/logo/logo.png "$PKG/usr/share/icons/hicolor/512x512/apps/piliplus.png"

for f in postinst postrm prerm; do
  if [ -f "assets/linux/DEBIAN/$f" ]; then
    cp "assets/linux/DEBIAN/$f" "$PKG/DEBIAN/$f"
    chmod 0755 "$PKG/DEBIAN/$f"
  fi
done

# 架构与版本
sed -i "s/^Architecture:.*/Architecture: ${ARCH}/" "$PKG/DEBIAN/control"
sed -i "s/version_need_change/${VERSION}/" "$PKG/DEBIAN/control"

# 安装大小
SIZE_KB=$(du -sk --apparent-size "$PKG/opt" | awk '{print int($1*1024/1024 + 0.999)}')
sed -i "s/size_need_change/${SIZE_KB}/" "$PKG/DEBIAN/control"

# control 依赖补充 webkit / appindicator
if ! grep -q "libwebkit2gtk" "$PKG/DEBIAN/control"; then
  sed -i 's|^Depends: libgtk-3-0t64,|Depends: libgtk-3-0t64,\n         libwebkit2gtk-4.1-0t64 \| libwebkit2gtk-4.1-0,\n         libayatana-appindicator3-1,|' "$PKG/DEBIAN/control"
fi

# md5sums
( cd "$PKG" && find opt usr -type f -exec md5sum {} \; > DEBIAN/md5sums )
chmod 0644 "$PKG/DEBIAN/control" "$PKG/DEBIAN/md5sums"

dpkg-deb --build --root-owner-group "$PKG"
echo "built: ${PKG}.deb"
ls -lh "${PKG}.deb"
