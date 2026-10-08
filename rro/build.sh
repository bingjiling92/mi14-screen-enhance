#!/usr/bin/env bash
# 编译最低亮度 RRO —— 在电脑上跑（需要 Android SDK build-tools）
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
#
# 用法:
#   ANDROID_SDK_ROOT=~/Android/Sdk bash build.sh
# 产物:
#   mi14_dimfloor.apk   → 拷到手机 /data/adb/mi14_screen_enhance/rro/ 后重启即可
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
    for c in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" /usr/lib/android-sdk; do
        [ -d "$c" ] && SDK="$c" && break
    done
fi
[ -n "$SDK" ] && [ -d "$SDK" ] || { echo "!! 找不到 Android SDK，请设置 ANDROID_SDK_ROOT"; exit 1; }

BT="$(ls -d "$SDK"/build-tools/* 2>/dev/null | sort -V | tail -1 || true)"
[ -n "${BT:-}" ] || { echo "!! 找不到 build-tools（需要 aapt2/zipalign/apksigner）"; exit 1; }
PLATFORM="$(ls -d "$SDK"/platforms/android-* 2>/dev/null | sort -V | tail -1 || true)"
[ -n "${PLATFORM:-}" ] || { echo "!! 找不到 platforms/android-*，需要 android.jar"; exit 1; }

echo "SDK      = $SDK"
echo "build-tools = $BT"
echo "platform = $PLATFORM"

AAPT2="$BT/aapt2"; ZIPALIGN="$BT/zipalign"; APKSIGNER="$BT/apksigner"

echo "== 1/5 清理 =="
rm -rf compiled.zip unsigned.apk aligned.apk mi14_dimfloor.apk
[ -f keystore.jks ] || {
    echo "== 生成自签名 keystore（overlay 只需「有签名」，分区 preinstall overlay 不做签名策略校验）=="
    keytool -genkeypair -keystore keystore.jks -storepass android -keypass android \
        -alias mi14 -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=mi14 dimfloor, O=bingjiling92" >/dev/null 2>&1
}

echo "== 2/5 aapt2 compile =="
"$AAPT2" compile --dir res -o compiled.zip

echo "== 3/5 aapt2 link =="
"$AAPT2" link -o unsigned.apk \
    -I "$PLATFORM/android.jar" \
    --manifest AndroidManifest.xml \
    --min-sdk-version 30 --target-sdk-version 35 \
    compiled.zip

echo "== 4/5 zipalign =="
"$ZIPALIGN" -f 4 unsigned.apk aligned.apk

echo "== 5/5 apksigner =="
"$APKSIGNER" sign --ks keystore.jks --ks-pass pass:android --key-pass pass:android \
    --out mi14_dimfloor.apk aligned.apk
"$APKSIGNER" verify --print-certs mi14_dimfloor.apk | head -3

rm -f compiled.zip unsigned.apk aligned.apk
echo
echo "== 完成 =="
echo "产物: $HERE/mi14_dimfloor.apk"
echo "下一步:"
echo "  adb push mi14_dimfloor.apk /sdcard/"
echo "  # 手机上（root）:"
echo "  mkdir -p /data/adb/mi14_screen_enhance/rro"
echo "  cp /sdcard/mi14_dimfloor.apk /data/adb/mi14_screen_enhance/rro/"
echo "  # 重启（本模块会自动把它挂到 /product/overlay/ 并尝试启用）"
