#!/system/bin/sh
# 小米14 屏幕基础亮度增强 —— 开机生成并挂载
#
# Copyright (c) 2026 bingjiling92
# SPDX-License-Identifier: MIT
#
# 原理：framework 的 DisplayDeviceConfig（system_server 侧）在开机时读
#   /product/etc/displayconfig/display_id_<ID>.xml   （优先）
#   /vendor/etc/displayconfig/display_id_<ID>.xml    （回退）
# 其中 <transitionPoint> 就是「非 HBM 状态下的亮度天花板」。
#
# 本模块不随包分发小米原厂文件，而是开机时从设备自己的原厂文件现场派生改写版
# （只动 <transitionPoint> / <minimumLux> 两个标签的值），再 mount --bind 覆盖回去。
#
# 安全策略：任何一步校验不过就「不挂载」，直接保持原厂行为。

MODDIR=${0%/*}
WORK=/data/adb/mi14_screen_enhance
LOG="$WORK/status.log"
GEN="$WORK/gen"
KNOWN_ID=4630947082089526659

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [pfd] $*" >> "$LOG"; }

mkdir -p "$WORK" 2>/dev/null
: > "$LOG"
log "start MODDIR=$MODDIR"

# ---------- 1. 档位 -> 目标值 ----------
PROF=$(grep -o '^[[:space:]]*PROFILE=[A-Za-z0-9_-]*' "$MODDIR/config.conf" 2>/dev/null | head -1 | cut -d= -f2)
case "$PROF" in
    balanced|safe) TP_NEW=0.808082041 ;;
    max|high)      TP_NEW=0.952386766 ;;
    *)             log "档位 '$PROF' 非法，回退 max"; PROF=max; TP_NEW=0.952386766 ;;
esac

# 阳光屏（HBM）介入所需环境光：留空 = 保持原厂；填数字则改成该值。
# 与亮度上限解耦——只有你真的想改才改，避免顺带引入热/耗电副作用。
RAW_LUX=$(sed -n 's/^[[:space:]]*SUNLIGHT_MIN_LUX=[[:space:]]*\([^[:space:]]*\).*/\1/p' "$MODDIR/config.conf" 2>/dev/null | head -1)
LUX_NEW=""
case "$RAW_LUX" in
    '') ;;
    *[!0-9]*) log "SUNLIGHT_MIN_LUX 非纯数字('$RAW_LUX')，保持原厂" ;;
    *) LUX_NEW=$RAW_LUX ;;
esac
log "profile=$PROF  transitionPoint->$TP_NEW  minimumLux->${LUX_NEW:-保持原厂}"

# 硬性约束：framework 中 transitionPoint >= backlightMaximum(1.0) 会抛
# IllegalArgumentException，且该异常不在 initFromFile 的 catch 列表里，
# 可能直接拖崩 system_server。这里必须卡死在 0.x。
case "$TP_NEW" in
    0.*) f=${TP_NEW#0.}; case "$f" in ''|*[!0-9]*) log "目标值非法: $TP_NEW"; exit 0 ;; esac ;;
    *)   log "目标值非法(必须 0.x 且 <1.0): $TP_NEW"; exit 0 ;;
esac

# ---------- 2. 设备校验 ----------
DEV=$(getprop ro.product.device)
if [ "$DEV" != "houji" ]; then
    log "非小米14(houji) 设备: $DEV —— 放弃挂载（不做任何改动）"
    exit 0
fi

# ---------- 3. 确定 display id ----------
# 正常情况 /product 下只有本机内置屏的一个 display_id_*.xml；
# 若数量不为 1（ROM 变动），回退到 houji 的已知 ID。
DISP_ID=""; n=0
for x in /product/etc/displayconfig/display_id_*.xml; do
    [ -f "$x" ] || continue
    n=$((n + 1))
    DISP_ID=$(basename "$x" .xml); DISP_ID=${DISP_ID#display_id_}
done
if [ "$n" != "1" ]; then
    log "/product 下发现 $n 个 display_id 配置，回退已知 ID $KNOWN_ID"
    DISP_ID=$KNOWN_ID
fi
SUBPATH="etc/displayconfig/display_id_$DISP_ID.xml"
log "display_id=$DISP_ID"

# ---------- 4. 现场派生 ----------
gen_one() {
    src="$1"; dst="$2"
    [ -f "$src" ] || return 1
    mkdir -p "${dst%/*}" 2>/dev/null
    sed -e "s#\(<transitionPoint>\)[^<]*\(</transitionPoint>\)#\1$TP_NEW\2#" "$src" > "$dst" 2>/dev/null || return 1
    if [ -n "$LUX_NEW" ]; then
        sed -i "s#\(<minimumLux>\)[^<]*\(</minimumLux>\)#\1$LUX_NEW\2#" "$dst" 2>/dev/null || return 1
    fi
    # 目标值必须真的写进去了（防 ROM 改名 / sed 失配）
    grep -q "<transitionPoint>$TP_NEW</transitionPoint>" "$dst" 2>/dev/null || return 1
    if [ -n "$LUX_NEW" ]; then
        grep -q "<minimumLux>$LUX_NEW</minimumLux>" "$dst" 2>/dev/null || return 1
    fi
    # 结构完整性
    for tag in '<displayConfiguration>' '<screenBrightnessMap>' '<highBrightnessMode' '</displayConfiguration>'; do
        grep -q -- "$tag" "$dst" 2>/dev/null || return 1
    done
    # 改完后原厂其余内容应原样保留（行数与源一致）
    [ "$(wc -l < "$dst")" = "$(wc -l < "$src")" ] || return 1
    return 0
}

SP=""; SV=""
for v in product vendor; do
    s="/$v/$SUBPATH"
    [ -f "$s" ] || continue
    if gen_one "$s" "$GEN/$v/$SUBPATH"; then
        log "已派生 $GEN/$v/$SUBPATH"
        [ "$v" = product ] && SP=1 || SV=1
    else
        log "派生失败: $s"
    fi
done
[ -n "$SP" ] || { log "product 侧未派生成功 —— 放弃挂载，保持原厂"; exit 0; }

# ---------- 5. 挂载 ----------
for v in product vendor; do
    s="$GEN/$v/$SUBPATH"; d="/$v/$SUBPATH"
    [ -f "$s" ] || { log "跳过(源不存在) $s"; continue; }
    [ -f "$d" ] || { log "跳过(目标不存在) $d"; continue; }
    if mount --bind "$s" "$d" 2>/dev/null; then
        chown root:root "$d" 2>/dev/null
        chmod 0644 "$d" 2>/dev/null
        restorecon "$d" 2>/dev/null
        log "已挂载 $s -> $d"
    else
        log "挂载失败 $s -> $d"
    fi
done
# ---------- 6. 可选：最低亮度 RRO ----------
# 本模块改不了最低亮度（见 README「关于最低亮度」）。若你把自行编译的 overlay
# APK 放到 $WORK/rro/，这里把它挂进 /product/overlay/，service.sh 再执行
# cmd overlay enable。没有该 APK 时这一步什么都不做。
for apk in "$WORK/rro"/*.apk; do
    [ -f "$apk" ] || continue
    d="/product/overlay/$(basename "$apk")"
    if mount --bind "$apk" "$d" 2>/dev/null; then
        chown root:root "$d" 2>/dev/null
        chmod 0644 "$d" 2>/dev/null
        restorecon "$d" 2>/dev/null
        log "已挂载 RRO $apk -> $d"
    else
        log "RRO 挂载失败 $apk -> $d"
    fi
done

log "done"
