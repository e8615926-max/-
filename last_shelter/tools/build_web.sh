#!/usr/bin/env bash
# Веб-сборка LAST SHELTER.
# 1. Экспорт из Godot (пресет «Web», оболочка web/shell.html).
# 2. Движок и пакет игры сжимаются gzip и получают имена engine.wasm и game-data.wasm:
#    хостинг страниц отдаёт только известные типы файлов, а оболочка сама распаковывает их в браузере.
# Готовый сайт — в build/web/site. Запуск: GODOT=/путь/к/godot tools/build_web.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
OUT=build/web
rm -rf "$OUT"
mkdir -p "$OUT/export" "$OUT/site"
"$GODOT" --headless --path . --export-release "Web" "$OUT/export/index.html"
cp "$OUT/export/index.html" "$OUT/export/index.js" "$OUT/export/index.audio.worklet.js" "$OUT/site/"
gzip -9 -n -c "$OUT/export/index.wasm" > "$OUT/site/engine.wasm"
gzip -9 -n -c "$OUT/export/index.pck" > "$OUT/site/game-data.wasm"
ls -la "$OUT/site"
