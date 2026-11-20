#!/usr/bin/env bash
# 修复 media_kit 在 Wayland 下的视频输出回退软渲染问题。
#
# 背景：Flutter 3.4x 上 VideoOutput 常在非渲染线程创建，
# eglGetCurrentDisplay() 返回 EGL_NO_DISPLAY，media_kit 因此固定走
# S/W 渲染 —— 表现为画面撕裂、CPU 占用飙升、弹幕掉帧。
# 补丁在拿不到 Flutter 的 EGL 上下文时，自行用
# eglGetPlatformDisplayEXT(EGL_PLATFORM_WAYLAND_EXT) 创建 display，
# 并补上 EGLConfig 的兜底选择。
#
# 注意：media_kit 与 media_kit_video 来自不同的 git 源，
# 负责 Linux 视频输出的是 media_kit_video（bggRGjQaUbCoE/media-kit），
# 必须精确定位到包含 media_kit_video/linux/video_output.cc 的那个仓库。
set -uo pipefail
WS="${1:-$PWD}"
PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

patch_file="$WS/lib/scripts/media_kit/egl_wayland_fallback.patch"
if [ ! -f "$patch_file" ]; then
  echo "WARN: patch not found: $patch_file"; exit 0
fi

# 精确找出真正包含 linux/video_output.cc 的 media_kit_video 仓库
target=""
while IFS= read -r cc; do
  [ -z "$cc" ] && continue
  repo_root=$(cd "$(dirname "$cc")/../.." 2>/dev/null && pwd)
  [ -z "$repo_root" ] && continue
  if [ -d "$repo_root/.git" ] || git -C "$repo_root" rev-parse 2>/dev/null >/dev/null; then
    target="$repo_root"
    echo "candidate: $target"
  fi
done <<EOF
$(find "$PUB_CACHE" -path "*media_kit_video/linux/video_output.cc" 2>/dev/null)
EOF

if [ -z "$target" ]; then
  echo "WARN: no media_kit_video source with linux/video_output.cc found"
  find "$PUB_CACHE" -maxdepth 3 -type d -name "media_kit*" 2>/dev/null | head -10
  exit 0
fi

echo "patching: $target/media_kit_video/linux/video_output.cc"
cd "$target" || exit 0

if grep -q "owns_egl_display" media_kit_video/linux/video_output.cc 2>/dev/null; then
  echo "EGL patch already applied, skip"
  exit 0
fi

if git apply --check "$patch_file" 2>/dev/null; then
  git apply "$patch_file" && echo "applied EGL wayland fallback patch OK"
else
  echo "FAILED: patch does not apply; aborting so build fails loudly"
  git apply --check -v "$patch_file" 2>&1 | head -20
  exit 1
fi
exit 0
