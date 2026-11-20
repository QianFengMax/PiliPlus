#!/usr/bin/env bash
# 替代 build.ps1：生成版本号与 pili_release.json
set -euo pipefail
WS="${1:-$PWD}"
cd "$WS"

version_code=$(git rev-list --count HEAD | tr -d ' ')
commit_hash=$(git rev-parse HEAD)
version_name=$(grep -E '^version:\s*[0-9.]+' pubspec.yaml | head -1 | sed -E 's/^version:\s*([0-9.]+).*/\1/')
[ -z "$version_name" ] && { echo "version not found"; exit 1; }

python3 - "$version_name" "$version_code" <<'PY'
import re, sys, pathlib
name, code = sys.argv[1], sys.argv[2]
p = pathlib.Path('pubspec.yaml'); s = p.read_text(encoding='utf-8')
s = re.sub(r'^version:\s*[0-9.]+\S*', f'version: {name}+{code}', s, count=1, flags=re.M)
p.write_text(s, encoding='utf-8')
PY

python3 - "$version_name" "$version_code" "$commit_hash" <<'PY'
import json, sys, time, pathlib
name, code, commit = sys.argv[1], sys.argv[2], sys.argv[3]
data = {'pili.name': name, 'pili.code': int(code),
        'pili.hash': commit, 'pili.time': int(time.time())}
pathlib.Path('pili_release.json').write_text(
    json.dumps(data, separators=(',', ':')), encoding='utf-8')
PY

echo "version=${version_name}+${version_code}"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "version=${version_name}+${version_code}" >> "$GITHUB_ENV"
fi
cat pili_release.json
