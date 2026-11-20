#!/usr/bin/env bash
# 替代 patch.ps1：给 Flutter SDK 打项目补丁
set -uo pipefail
WS="${1:-$PWD}"
PLATFORM="$(echo "${2:-linux}" | tr '[:upper:]' '[:lower:]')"
cd "$WS"

export GIT_AUTHOR_NAME=ci GIT_AUTHOR_EMAIL=example@example.com
export GIT_COMMITTER_NAME=ci GIT_COMMITTER_EMAIL=example@example.com

FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(command -v flutter)")")}"
echo "FLUTTER_ROOT=$FLUTTER_ROOT"
cd "$FLUTTER_ROOT"
git config --global --add safe.directory "$FLUTTER_ROOT" 2>/dev/null || true

# linux 平台需要重置 SDK
case "$PLATFORM" in
  linux|android) git reset --hard HEAD >/dev/null 2>&1 || true ;;
esac

PATCHES=(
  modal_barrier
  mouse_cursor
  image_anim
  layout_builder
  navigation_drawer
  popup_menu
  fab
  null_safety_for_selectable_region
  selectable_region
  text_selection
  text_field
  scroll_position
  scrollable
  scrollable_gesture
  draggable_scrollable_sheet
  scaffold
  text
  text_painter
  sliver
  refresh_indicator
  double_tap_gesture
  media_query
)

case "$PLATFORM" in
  android) PATCHES+=(bottom_sheet_android scroll_view navigator) ;;
  ios)     PATCHES+=(scroll_view bottom_sheet_ios_flutter navigator) ;;
esac

failed=""
for p in "${PATCHES[@]}"; do
  f="$WS/lib/scripts/$p.patch"
  [ -f "$f" ] || { echo "MISSING $f"; continue; }
  if git apply "$f" 2>/dev/null; then
    echo "applied $p"
  else
    if git apply --reverse --check "$f" 2>/dev/null; then
      echo "skip $p (already applied / superseded by upstream)"
    else
      echo "FAILED $p"
      failed="$failed $p"
    fi
  fi
done

cd "$WS"
if [ -n "$failed" ]; then
  echo "some patches failed (non-fatal):$failed"
fi
exit 0
