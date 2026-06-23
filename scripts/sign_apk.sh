#!/usr/bin/env bash
# 对 Godot 导出的 APK 签名（v1+v2+v3，兼容新旧 Android）
set -euo pipefail

APK="${1:-D:/folat-island/build/FolatIsland.apk}"
SRC="${2:-D:/folat-island/build/FolatIsland-aligned.apk}"
APKSIGNER="${APKSIGNER:-$LOCALAPPDATA/Android/Sdk/build-tools/34.0.0/apksigner.bat}"
KS="${KS:-$APPDATA/Godot/keystores/debug.keystore}"
JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"

if [[ ! -f "$SRC" ]]; then
	SRC="${APK%.apk}-unsigned.apk"
fi
if [[ ! -f "$SRC" ]]; then
	echo "找不到待签名 APK，请先导出: build/FolatIsland-unsigned.apk"
	exit 1
fi
if [[ ! -f "$KS" ]]; then
	echo "找不到 debug keystore: $KS"
	exit 1
fi

export JAVA_HOME
cp -f "$SRC" "$APK"
"$APKSIGNER" sign \
	--ks "$KS" \
	--ks-pass pass:android \
	--key-pass pass:android \
	--ks-key-alias androiddebugkey \
	--v1-signing-enabled true \
	--v2-signing-enabled true \
	--v3-signing-enabled true \
	"$APK"

"$APKSIGNER" verify --verbose "$APK" >/dev/null
echo "已签名: $APK"
