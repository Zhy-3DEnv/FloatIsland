#!/usr/bin/env bash
# FolatIsland：导出 → 签名 → 安装（USB 调试）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-C:/Users/zhouhuiyuan/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe}"
ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
ZIPALIGN="${ZIPALIGN:-$LOCALAPPDATA/Android/Sdk/build-tools/34.0.0/zipalign.exe}"
export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"

UNSIGNED="$ROOT/build/FolatIsland-unsigned.apk"
ALIGNED="$ROOT/build/FolatIsland-aligned.apk"
APK="$ROOT/build/FolatIsland.apk"

mkdir -p "$ROOT/build"

echo "==> 导出 Debug APK（未签名）..."
"$GODOT" --headless --path "$ROOT" --export-debug "Android" "$UNSIGNED"

echo "==> zipalign..."
"$ZIPALIGN" -f -p 4 "$UNSIGNED" "$ALIGNED"

echo "==> apksigner 签名..."
bash "$ROOT/scripts/sign_apk.sh" "$APK" "$ALIGNED"

echo "==> 检测设备..."
"$ADB" devices -l
DEVICE_COUNT=$("$ADB" devices | grep -c 'device$' || true)
if [[ "$DEVICE_COUNT" -lt 1 ]]; then
	echo "未检测到手机，APK 已生成: $APK"
	exit 1
fi

echo "==> 安装..."
"$ADB" install -r "$APK"
echo "完成。在手机上打开 FolatIsland。"
