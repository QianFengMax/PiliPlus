#!/usr/bin/env bash
# 替代 patch.ps1 的 material_ui / cupertino_ui 部分
set -uo pipefail
WS="${1:-$PWD}"
PLATFORM="$(echo "${2:-linux}" | tr '[:upper:]' '[:lower:]')"
cd "$WS"

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

normalize_crlf() {
  local f="$1"
  if grep -q $'\r' "$f" 2>/dev/null; then
    sed -i 's/\r$//' "$f"
  fi
}

patch_pkg() {
  local pkg_prefix="$1"; shift
  local dir
  dir=$(ls -d "$PUB_CACHE/hosted/pub.dev/${pkg_prefix}"-* 2>/dev/null | sort -V | tail -1)
  if [ -z "$dir" ]; then
    echo "WARN: $pkg_prefix not found in $PUB_CACHE"
    return 0
  fi
  echo "patching $dir"
  local patches=("$@")
  local failed=""
  for rel in "${patches[@]}"; do
    f="$WS/lib/scripts/$rel"
    [ -f "$f" ] || continue
    normalize_crlf "$f"
    if ( cd "$dir" && git apply "$f" 2>/dev/null ); then
      echo "  applied $rel"
    else
      echo "  FAILED $rel"
      failed="$failed $rel"
    fi
  done
  [ -n "$failed" ] && echo "  failed:$failed"
  return 0
}

MATERIAL=(material/modal_barrier_material.patch
          material/navigation_drawer.patch
          material/popup_menu.patch
          material/fab.patch
          material/text_field.patch
          material/scaffold.patch
          material/refresh_indicator.patch
          material/tabs.patch)

case "$PLATFORM" in
  android) MATERIAL+=(material/bottom_sheet_android.patch) ;;
  ios)     MATERIAL+=(material/bottom_sheet_ios_flutter_material.patch) ;;
esac

patch_pkg "material_ui" "${MATERIAL[@]}"

CUPERTINO=()
case "$PLATFORM" in
  ios) CUPERTINO+=("cupertino/bottom_sheet_ios_flutter.patch") ;;
esac
if [ ${#CUPERTINO[@]} -gt 0 ]; then
  patch_pkg "cupertino_ui" "${CUPERTINO[@]}"
fi

exit 0
