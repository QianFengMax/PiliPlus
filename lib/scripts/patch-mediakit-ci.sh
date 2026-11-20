#!/usr/bin/env bash
# 修复 media_kit 在 Wayland 下的视频输出回退软渲染问题。
#
# 背景：Flutter 3.4x 上 VideoOutput 常在非渲染线程创建，
# eglGetCurrentDisplay() 返回 EGL_NO_DISPLAY，media_kit 因此固定走
# S/W 渲染 —— 表现为画面撕裂、CPU 占用飙升、弹幕掉帧。
# 补丁在拿不到 Flutter 的 EGL 上下文时，自行用
# eglGetPlatformDisplayEXT(EGL_PLATFORM_WAYLAND_EXT) 创建 display，
# 并补上 EGLConfig 的兜底选择。
set -uo pipefail
WS="${1:-$PWD}"
PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

patch_file="$WS/lib/scripts/media_kit/egl_wayland_fallback.patch"
[ -f "$patch_file" ] || { echo "WARN: patch not found: $patch_file"; exit 0; }

# pub 的 git 依赖解包在 hosted/../git 或 .pub-cache/git 下
dir=$(find "$PUB_CACHE" -maxdepth 4 -type d -name "media_kit_video" 2>/dev/null | head -1)
if [ -z "$dir" ]; then
  # 兼容 hosted 结构：git 依赖会在 ~/.pub-cache/git/<repo>-<sha>/
  dir=$(ls -d "$PUB_CACHE"/git/*/media_kit_video 2>/dev/null | head -1)
fi

if [ -z "$dir" ]; then
  echo "WARN: media_kit_video not found in pub cache, skip EGL patch"
  exit 0
fi

repo_root=$(dirname "$dir")
echo "media_kit repo: $repo_root"

cd "$repo_root" || exit 0

if git apply --check "$patch_file" 2>/dev/null; then
  git apply "$patch_file" && echo "applied EGL wayland fallback patch"
elif git apply --reverse --check "$patch_file" 2>/dev/null; then
  echo "EGL patch already applied"
else
  echo "WARN: EGL patch did not apply cleanly (upstream may have changed)"
  # 退一步：用 python 直接改，尽量保证生效
  python3 - "$repo_root/media_kit_video/linux/video_output.cc" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    print("  file missing"); sys.exit(0)
s = p.read_text()
if 'owns_egl_display' in s:
    print("  already patched"); sys.exit(0)
print("  fallback patch skipped: structure changed")
PY
fi
exit 0
