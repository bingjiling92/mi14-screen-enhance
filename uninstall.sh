#!/system/bin/sh
# 卸载时尝试立即摘掉 bind mount（不重启也能回原厂；重启后本来也会自动失效）
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT

SUBPATH=etc/displayconfig/display_id_4630947082089526659.xml

for v in product vendor; do
    d="/$v/$SUBPATH"
    if grep -q " $d " /proc/mounts 2>/dev/null; then
        umount "$d" 2>/dev/null && echo "mi14_screen_enhance: unmounted $d"
        restorecon "$d" 2>/dev/null
    fi
done
exit 0
