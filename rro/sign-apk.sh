#!/bin/sh
# 一键：生成密钥（若缺）-> 签名 aligned.apk -> mi14_dimfloor.apk
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
# 用法: sh sign-apk.sh <工程目录>
set -e
SRC="${1:-$(cd "$(dirname "$0")" && pwd)}"
cd "$SRC"
if [ ! -f key.pem ] || [ ! -f cert.pem ]; then
    echo "== 生成自签名密钥（分区 preinstall overlay 不做签名策略校验，自签即可）=="
    openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
        -days 10000 -nodes -subj "/CN=mi14 dimfloor/O=bingjiling92" >/dev/null 2>&1
fi
python3 sign-apk.py aligned.apk mi14_dimfloor.apk key.pem cert.pem
ls -la mi14_dimfloor.apk
