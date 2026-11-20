#!/usr/bin/env bash
# 修复 nativeapi 在 Dart 3.14+ 下的编译错误：
# run_native_app.dart 使用了 Dart 3.13 的实验 API Isolate.create，
# 该 API 在 3.14 已移除且此函数不会被 Flutter 调用（官方注明 Not for Flutter），
# 因此将其降级为直接调用 main()。
set -uo pipefail
PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

dir=$(ls -d "$PUB_CACHE/hosted/pub.dev/nativeapi"-* 2>/dev/null | sort -V | tail -1)
if [ -z "$dir" ]; then
  echo "WARN: nativeapi not found, skip"
  exit 0
fi
f="$dir/lib/src/run_native_app.dart"
[ -f "$f" ] || { echo "WARN: $f not found, skip"; exit 0; }

if ! grep -q "Isolate.create" "$f"; then
  echo "nativeapi already compatible, skip"
  exit 0
fi

python3 - "$f" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
start = s.find('void runNativeApp(void Function() main) {')
end = s.find('\nvoid _start(void Function() main) {')
if start < 0 or end < 0:
    print('pattern not found, skip'); sys.exit(0)
new = ('void runNativeApp(void Function() main) {\n'
       '  // Dart 3.14 移除了 Isolate.create；Flutter 不调用此函数。\n'
       '  main();\n'
       '}\n')
p.write_text(s[:start] + new + s[end:])
print('patched', p)
PY
