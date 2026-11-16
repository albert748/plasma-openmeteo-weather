#!/usr/bin/env bash
# 重新安装本仓的 Plasma 天气部件，并保留本地默认坐标。
# 用法：sync-install.sh            （从本仓安装/升级）
#      sync-install.sh --upstream （先 rebase 到 tiamed 上游最新，再安装）
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="com.local.openmeteo.weathercard"
INST="$HOME/.local/share/plasma/plasmoids/$ID"

cd "$SRC"

if [ "${1:-}" = "--upstream" ]; then
    echo "== rebase 到上游 =="
    git fetch upstream --tags
    git rebase upstream/main
fi

echo "== 安装到用户级 KPackage =="
kpackagetool6 -t Plasma/Applet -u "$SRC" 2>/dev/null || kpackagetool6 -t Plasma/Applet -i "$SRC"

echo "== 复原默认坐标（安装副本） =="
python3 - "$INST/contents/config/main.xml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'(<entry name="locationName"[^>]*>.*?<default>)[^<]*(</default>)', r'\1Chongqing\2', s, flags=re.S)
s = re.sub(r'(<entry name="latitude"[^>]*>.*?<default>)[^<]*(</default>)', r'\g<1>29.5603\2', s, flags=re.S)
s = re.sub(r'(<entry name="longitude"[^>]*>.*?<default>)[^<]*(</default>)', r'\g<1>106.5577\2', s, flags=re.S)
open(p, 'w', encoding='utf-8').write(s)
print('main.xml 默认坐标 = Chongqing / 29.5603,106.5577')
PY

echo "== 冒烟 + 重载面板 =="
QT_QPA_PLATFORM=offscreen timeout 12 /usr/sbin/plasmawindowed "$ID" 2>&1 | grep -iE 'error|warning|failed' || true
systemctl --user restart plasma-plasmashell

echo
echo "完成。上游 PR: https://github.com/tiamed/plasma-openmeteo-weather/pull/2"
