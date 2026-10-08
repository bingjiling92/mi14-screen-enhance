#!/system/bin/sh
# 在手机本机（真机环境，非沙箱）里用 Termux 的工具链编译 RRO —— 不含签名步骤
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
# 用法（root）:
#   sh build-phone.sh <工程目录>
set -e
SRC="${1:-/data/data/com.termux/files/home/mi14-rro}"
P=/data/data/com.termux/files/usr
export PATH="$P/bin:/system/bin"
export LD_LIBRARY_PATH="$P/lib"
export TMPDIR="$P/tmp"
mkdir -p "$TMPDIR"

cd "$SRC"
rm -f compiled.zip unsigned.apk aligned.apk
echo "== aapt2 compile =="
aapt2 compile --dir res -o compiled.zip
echo "== aapt2 link (unsigned) =="
aapt2 link -o unsigned.apk \
    -I "$P/share/aapt/android.jar" \
    --manifest AndroidManifest.xml \
    --min-sdk-version 29 --target-sdk-version 29 \
    compiled.zip
echo "== zipalign =="
zipalign -f 4 unsigned.apk aligned.apk
ls -la aligned.apk
echo "== OK: $SRC/aligned.apk (待签名) =="
