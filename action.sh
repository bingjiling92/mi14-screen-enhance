#!/system/bin/sh
# KernelSU 管理器「操作」按钮：打印当前状态
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT

MODDIR=${0%/*}
WORK=/data/adb/mi14_screen_enhance
SUBPATH=etc/displayconfig/display_id_4630947082089526659.xml

echo "==== 小米14 屏幕基础亮度增强 ===="
echo "Copyright (c) 2026 bingjiling92  |  MIT License"
echo "档位: $(grep -o 'PROFILE=[A-Za-z0-9_-]*' "$MODDIR/config.conf" 2>/dev/null | head -1 | cut -d= -f2)"
echo ""
echo "---- bind mount ----"
if grep -q 'displayconfig' /proc/mounts 2>/dev/null; then
    grep 'displayconfig' /proc/mounts
else
    echo "（未挂载：需要重启，或看 $WORK/status.log）"
fi
echo ""
echo "---- 实际生效值 ----"
dumpsys display 2>/dev/null | grep -m1 'mCachedBrightnessInfo.brightnessMax='
dumpsys display 2>/dev/null | grep -m1 'mCachedBrightnessInfo.hbmTransitionPoint='
echo ""
echo "---- 挂载点当前内容 ----"
grep -o '<transitionPoint>[^<]*' "/product/$SUBPATH" 2>/dev/null
grep -o '<minimumLux>[^<]*' "/product/$SUBPATH" 2>/dev/null
echo ""
echo "---- 日志尾部 ----"
tail -n 15 "$WORK/status.log" 2>/dev/null || echo "(无日志)"
