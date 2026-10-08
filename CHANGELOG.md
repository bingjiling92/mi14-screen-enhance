# 更新日志 / Changelog

## v1.2 (2026-10-08)

* **上限再抬一档**：默认档位改为 `max`（`<transitionPoint>` = `0.952386766`，基础亮度上限
  **500 → 1400 nits**）；原 1000 nits 档改名语义保留为 `balanced`。
* **把 `minimumLux` 从档位里解耦**：v1.1 的 `max` 档会顺带把阳光屏阈值从 5882 改成 2000，
  这属于热控副作用，用户没要求就不该动。现在改成独立开关
  `SUNLIGHT_MIN_LUX=`（留空 = 保持原厂），默认完全不动。
* 档位名增加别名：`high` = `max`、`safe` = `balanced`；档位填错回退 `max`。
* README 新增「**关于最低亮度**」一节，说明为什么最低亮度**不能**由本模块调整
  （附 framework 字节码证据），以及可行的替代方案。

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
