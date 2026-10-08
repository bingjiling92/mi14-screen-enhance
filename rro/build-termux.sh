#!/data/data/com.termux/files/usr/bin/bash
# 在手机 Termux 里直接编译最低亮度 RRO —— 不需要电脑
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
#
# 依赖（Termux 里装）:
#   pkg install aapt2 apksigner zipalign openjdk-17
# aapt2 link 用的 android.jar 由 aapt2 包自带:
#   $PREFIX/share/aapt/android.jar
#
# 用法:
#   bash build-termux.sh
# 产物:
#   mi14_dimfloor.apk
set -euo pipefail

export PREFIX=/data/data/com.termux/files/usr
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib"
export HOME=/data/data/com.termux/files/home
export TMPDIR="$PREFIX/tmp"
export JAVA_HOME="$PREFIX/opt/openjdk"

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

AAPT2="$PREFIX/bin/aapt2"; ZIPALIGN="$PREFIX/bin/zipalign"; APKSIGNER="$PREFIX/bin/apksigner"
JAR="$PREFIX/share/aapt/android.jar"
[ -x "$AAPT2" ] || { echo "!! 缺 aapt2：pkg install aapt2"; exit 1; }
[ -f "$JAR" ]   || { echo "!! 缺 $JAR"; exit 1; }
command -v java >/dev/null || { echo "!! 缺 java：pkg install openjdk-17"; exit 1; }

echo "== 0/5 环境 =="; echo "aapt2=$(command -v aapt2)  java=$(command -v java)"

echo "== 1/5 清理 =="
rm -f compiled.zip unsigned.apk aligned.apk mi14_dimfloor.apk
if [ ! -f keystore.jks ]; then
    echo "== 生成自签名 keystore（分区 preinstall overlay 不做签名策略校验，自签即可）=="
    keytool -genkeypair -keystore keystore.jks -storepass android -keypass android \
        -alias mi14 -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=mi14 dimfloor, O=bingjiling92"
fi

echo "== 2/5 aapt2 compile =="
"$AAPT2" compile --dir res -o compiled.zip

echo "== 3/5 aapt2 link =="
"$AAPT2" link -o unsigned.apk -I "$JAR" --manifest AndroidManifest.xml \
    --min-sdk-version 30 --target-sdk-version 35 compiled.zip

echo "== 4/5 zipalign =="
"$ZIPALIGN" -f 4 unsigned.apk aligned.apk

echo "== 5/5 apksigner =="
"$APKSIGNER" sign --ks keystore.jks --ks-pass pass:android --key-pass pass:android \
    --out mi14_dimfloor.apk aligned.apk
"$APKSIGNER" verify --print-certs mi14_dimfloor.apk | head -3

rm -f compiled.zip unsigned.apk aligned.apk
echo
echo "== 完成: $HERE/mi14_dimfloor.apk =="
echo
echo "下一步（root）:"
echo "  mkdir -p /data/adb/mi14_screen_enhance/rro"
echo "  cp mi14_dimfloor.apk /data/adb/mi14_screen_enhance/rro/"
echo "  重启（本模块会挂载到 /product/overlay 并执行 cmd overlay enable）"
