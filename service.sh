#!/system/bin/sh
# 开机后自动采集「是否真的生效」的证据，写进状态日志。
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
# 只做读取，不改变任何行为。

WORK=/data/adb/mi14_screen_enhance
LOG="$WORK/status.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [svc] $*" >> "$LOG"; }

# 等 system_server / dumpsys 就绪（最多约 120s）
i=0
while [ "$i" -lt 60 ]; do
    dumpsys display 2>/dev/null | grep -q 'mCachedBrightnessInfo' && break
    sleep 2
    i=$((i + 1))
done

log "==== 生效证据 ===="

if grep -q 'displayconfig' /proc/mounts 2>/dev/null; then
    grep 'displayconfig' /proc/mounts 2>/dev/null | while read -r line; do
        log "mount: $line"
    done
else
    log "!! /proc/mounts 里没有 displayconfig 挂载 —— 模块没生效"
fi

dumpsys display 2>/dev/null | grep -m1 'mBacklight=' | while read -r line; do
    log "亮度表: $line"
done
dumpsys display 2>/dev/null | grep -m1 'mCachedBrightnessInfo.brightnessMax=' | while read -r line; do
    log "生效上限: $line"
done
dumpsys display 2>/dev/null | grep -m1 'mHbmData=HBM{' | while read -r line; do
    log "HBM: $line"
done
log "==== 证据结束 ===="

# ---- 可选：启用最低亮度 RRO ----
RRO_PKG=com.bingjiling92.mi14.dimfloor
if grep -q ' /product/overlay/' /proc/mounts 2>/dev/null; then
    i=0
    while [ "$i" -lt 30 ]; do
        cmd overlay list 2>/dev/null | grep -q "$RRO_PKG" && break
        sleep 2
        i=$((i + 1))
    done
    if cmd overlay list 2>/dev/null | grep -q "$RRO_PKG"; then
        cmd overlay enable --user 0 "$RRO_PKG" >> "$LOG" 2>&1 && log "已请求启用 RRO $RRO_PKG"
        cmd overlay list 2>/dev/null | grep "$RRO_PKG" | while read -r line; do
            log "overlay: $line"
        done
    else
        log "发现 /product/overlay 挂载，但没扫到覆盖包 $RRO_PKG"
    fi
    dumpsys display 2>/dev/null | grep -m1 -o 'mBacklightMinimum=[0-9.E-]*' | while read -r line; do
        log "最低亮度: $line"
    done
fi
