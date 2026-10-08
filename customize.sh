#!/sbin/sh
# 安装脚本（KernelSU / Magisk 通用）
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
SKIPUNZIP=0
[ ! "$MODPATH" ] && MODPATH=${0%/*}

command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v set_perm >/dev/null 2>&1 || set_perm() { chown $1:$2 "$3" 2>/dev/null; chmod $4 "$3" 2>/dev/null; }
command -v set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() { chown -R $1:$2 "$5" 2>/dev/null; chmod -R $4 "$5" 2>/dev/null; }

ui_print "************************************************"
ui_print "   小米14 屏幕基础亮度增强 v1.2"
ui_print "   Copyright (c) 2026 bingjiling92 | MIT"
ui_print "************************************************"
ui_print ""
ui_print "- 设备: $(getprop ro.product.model) ($(getprop ro.product.device))"

if [ "$(getprop ro.product.device)" != "houji" ]; then
  ui_print "! 警告: 本模块只适配小米14(houji)，其他设备上开机脚本会自行跳过，不会改动系统。"
fi

ui_print "- 档位: $(grep -o 'PROFILE=[A-Za-z0-9_-]*' "$MODPATH/config.conf" 2>/dev/null | head -1 | cut -d= -f2)"
ui_print "- 说明: 不随包分发小米原厂文件，开机时从设备自身原厂 displayconfig 现场派生"

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in post-fs-data.sh service.sh uninstall.sh action.sh; do
  [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
ui_print ""
ui_print "- 安装完成，重启后生效"
