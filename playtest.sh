#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-C:/Users/zhouhuiyuan/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe}"
echo "[playtest] 启动自动试玩（带窗口）..."
exec "$GODOT" --path "$ROOT" --script res://scripts/playtest/playtest_run.gd
