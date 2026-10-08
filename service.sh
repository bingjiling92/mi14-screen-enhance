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
