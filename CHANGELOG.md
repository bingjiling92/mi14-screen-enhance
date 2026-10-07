# 更新日志 / Changelog

## v1.1 (2026-10-07)

* **改为开机现场派生**：不再随包分发小米原厂 `displayconfig` XML。开机时从设备自身的
  `/product|/vendor/etc/displayconfig/display_id_<ID>.xml` 派生出改写版再 bind mount，
  仓库里不再包含任何小米文件。
* `display_id` 改为自动探测（`/product` 下唯一一个 `display_id_*.xml`），探测不唯一时
  回退到 houji 已知 ID，提升 ROM 变动后的健壮性。
* 新增派生后校验：目标值必须写入成功、必需标签齐全、行数与原厂一致，任何一项不过即放弃挂载。
* 状态日志改到 `/data/adb/mi14_screen_enhance/status.log`（与本机其他模块一致，卸载干净）。
* 全部文件加上版权与 SPDX 标识。

## v1.0 (2026-10-07)

* 首个版本。`transitionPoint` 0.499938 → 0.808082041（500 → 1000 nits），可选 `max` 档 1400 nits。
* 实测验证：重启后 `mCachedBrightnessInfo.brightnessMax=0.80808204`，
  并在 `lux=2308`（非阳光屏档位）下实测到 `nits=1000.0`。
