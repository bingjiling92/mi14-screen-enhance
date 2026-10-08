# 小米14 屏幕基础亮度增强

**mi14_screen_enhance** —— KernelSU / Magisk 模块，抬升小米14 (houji) 的屏幕**基础亮度天花板**。

> ## 版权 / Copyright
>
> **Copyright (c) 2026 bingjiling92**
>
> 本项目以 **MIT License** 发布，全文见 [LICENSE](LICENSE)。
> 第三方声明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
>
> 本仓库**不包含任何小米原厂文件**：模块在开机时从设备自身的 `displayconfig`
> 现场派生改写版，只在 `/data` 生成用于 bind mount 的副本，不写回系统分区。

---

## 一句话

小米14 在 **非 HBM（非阳光屏）状态下，亮度天花板被锁死在 500 nits** —— 亮度滑杆推到底、
室内、自动亮度，最高都只有 **500 nits**。本模块把它抬到 **1400 nits**（可退回 1000 nits 档）。

## 效果实测

| 档位 | `<transitionPoint>` | 滑杆上限 | 状态 |
|---|---|---|---|
| 原厂 | `0.499938` | 500 nits | — |
| `balanced` / `safe`（可选） | `0.808082041` | 1000 nits | ✅ 已实测 |
| **`max` / `high`（默认）** | `0.952386766` | **1400 nits** | ✅ 户外阳光档位实测达到过 |

装上重启后，`dumpsys display` 里的数值变化：

```
改前：mCachedBrightnessInfo.brightnessMax=0.499938
改后：mCachedBrightnessInfo.brightnessMax=0.95238674
```

以及实测的亮度事件（**证明亮度真的上去了**）：

```
16:29:09.022  BrightnessEvent: brt=0.80808204 (100.0%), nits= 1000.0, lux=2308.2, hbmMode=off
```

* `lux=2308` 远低于阳光屏门槛（5882 lux），说明这是**基础亮度**的提升，不是靠阳光屏蹭出来的。
* 同一台机器在改前，100% 滑杆室内只有 `nits=500.0`。
* 1400 nits 是本机户外阳光模式（`hbmMode=sunlight`）已经实测达到过的档位，属面板已验证范围。

> 再往上（>1400 nits）就进入亮度表里的 HDR 峰值区间（`1.0 = 2800 nits`），全屏持续不可持续，
> 且已超出 MIUI 自家热控表允许的范围，因此本模块不提供。

## 原理

framework（system_server 的 `DisplayDeviceConfig` + `HighBrightnessModeController`）会读：

```
/product/etc/displayconfig/display_id_<ID>.xml     ← 优先
/vendor/etc/displayconfig/display_id_<ID>.xml      ← 回退
```

而 AOSP 里这一句决定了日常亮度上限：

```java
float getCurrentBrightnessMax() {
    if (!deviceSupportsHbm() || isHbmCurrentlyAllowed()) {
        return mBrightnessMax;
    } else {
        return mHbmData.transitionPoint;   // ← 平时走这里
    }
}
```

`isHbmCurrentlyAllowed()` 要求「自动亮度开启 + 环境光 ≥ `minimumLux`」，所以
**`<transitionPoint>` 就是日常状态的亮度天花板**。小米14 的这个值是 `0.499938`（500 nits），
而滑杆最高会请求 `0.952386766`（1400 nits）——请求值落在 `(0.499938, 0.952386766]`
的这一大段行程全被夹平成同一个亮度，**推上去没反应**。

本模块只改这一个字段，把天花板抬到 `0.952386766`。

## 关于最低亮度（重要）

**本模块无法调整最低亮度**，这不属于它的能力范围。原因不是配置没找对，而是机制上不通：

设备自身 `services.jar` 里 `DisplayDeviceConfig.loadBrightnessConstraintsFromConfigXml()`
的签名是 `()V`（**根本不接收 XML 参数**），它只从 framework 资源取值：

```java
private void loadBrightnessConstraintsFromConfigXml() {
    Resources r = mContext.getResources();
    float f1 = r.getFloat(R.dimen.config_screenBrightnessSettingMinimumFloat); // 8.54597E-4
    float f2 = r.getFloat(R.dimen.config_screenBrightnessSettingMaximumFloat);
    if (f1 != -2.0f && f2 != -2.0f) {          // 两个都设了才走浮点路径
        mBacklightMinimum = f1;
        mBacklightMaximum = f2;
    } else {
        mBacklightMinimum = BrightnessSynchronizer.brightnessIntToFloat(
                r.getInteger(R.integer.config_screenBrightnessSettingMinimum));
        ...
    }
    mBrightnessDim = r.getFloat(R.dimen.config_screenBrightnessDimFloat); // 也是 8.54597E-4
}
```

而已核实的其它事实：

* `loadBrightnessMap()`（读 `<screenBrightnessMap>` 的那个方法）**从不给 `mBacklightMinimum` 赋值**。
* `constrainNitsAndBacklightArrays()` 反过来会用 `mBacklightMinimum` 去**夹住** XML 里的亮度表，
  所以往 XML 里塞更低的点也没用。
* 在设备上实测：`android:dimen/config_screenBrightnessSettingMinimumFloat` = `8.54597E-4`，
  与 `dumpsys display` 的 `mBacklightMinimum=8.54597E-4` 完全一致 —— 证实上面这条路径。
* 结论：**最低亮度由 framework 资源决定，只能靠 RRO（运行时资源覆盖）去改**。
  本机 `/product/overlay/AospFrameworkResOverlay.apk` 就在覆盖这个 dimen，说明它可被覆盖，
  但造一个 overlay APK 需要 `aapt2`（本机环境没有），而且覆盖 framework 资源通常要求
  overlay APK 具备平台级签名。
* 附带说明：`cmd overlay fabricate` 也做不到——它只接受整数类型（`dataType ∈ [16,31]`），
  而这个资源是 dimen/float。

### RRO 也不行（已实测到底）

「只有 RRO 能改」这句话在**这台 ROM 上同样走不通**。RRO 工程（见 [`rro/`](rro/README.md)）
已经做好、在手机上编译并签名、`pm install` 也装上了，但：

```
cmd overlay enable  -> 状态 STATE_NO_IDMAP
idmap2 create       -> no resources were overlaid -> failed to create idmap
```

两条硬性限制：

1. 覆盖 `android` 的 overlay 必须**与目标同签名**，或声明
   `<overlay android:targetName="...">`（实测不加 `targetName` 时 `pm install`
   直接失败；加了任意字符串就能装进去）。
2. 但真正卡死的是：**framework-res 一个具名 overlayable 都没有。**
   解析其 `resources.arsc`，包内 chunk 只有 `TYPE(0x0201) x465`、
   `TYPE_SPEC(0x0202) x48`、`STAGED_ALIAS(0x0206) x1` —— **没有
   `OVERLAYABLE(0x0204)`、也没有 `OVERLAYABLE_POLICY(0x0205)`**。
   没有 overlayable ⇒ 非平台签名的 overlay 无法映射其中任何资源，
   而平台私钥不在设备上。

**所以：本机最低亮度无法通过任何免平台签名的软件手段降低。** 完整证据与构建链保留在
[`rro/`](rro/README.md)，换 ROM 或拿到平台签名时可直接用。

**可以马上用的替代方案**：本机已支持 Android 自带的「**极暗 / Reduce bright colors**」
（`reduce_bright_colors_level` 可调，当前 57）。它是用色彩变换把亮度压到硬件下限**以下**，
正好就是「还能更暗」这件事：

```sh
settings put secure reduce_bright_colors_activated 1     # 开启
settings put secure reduce_bright_colors_level 100       # 调强度（越大越暗）
settings put secure reduce_bright_colors_activated 0     # 关闭
```

或直接用快捷设置里的「极暗」磁贴。

顺带一提：框架下限对应的面板原始背光是 `25 / 4095`，所以硬件本身**确实还有往下余量**——
只是那部分只能由 RRO 打开。

## 安装

```sh
# 方式一：KernelSU 管理器 → 模块 → 从本地安装
# 方式二：命令行
/data/adb/ksud module install /path/to/mi14_screen_enhance.zip

# 方式三：Magisk 管理器刷入
```

**重启后生效。** framework 只在开机时读一次这个配置，没有运行时重载入口。

## 配置

编辑 `/data/adb/modules/mi14_screen_enhance/config.conf`：

```ini
# 亮度上限档位
PROFILE=max          # 默认，1400 nits（别名 high）
# PROFILE=balanced   # 保守，1000 nits（别名 safe）

# 阳光屏（HBM）介入所需环境光，单位 lux
SUNLIGHT_MIN_LUX=    # 留空 = 保持原厂 5882；填 2000 可让阳光屏更早介入
```

改完**重启**生效。档位填错回退 `max`。

> `SUNLIGHT_MIN_LUX` 与亮度上限是**解耦**的：v1.1 曾把「改成 2000」捆在 `max` 档里，
> 那会顺带把热控负担提上去；现在不改它就完全保持原厂。

## 验证

```sh
# 模块状态日志（开机自检 + 生效证据，由 service.sh 自动采集）
cat /data/adb/mi14_screen_enhance/status.log

# 实时生效值：默认档应看到 brightnessMax=0.95238674
dumpsys display | grep -E 'mCachedBrightnessInfo.brightnessMax='

# 挂载点
grep displayconfig /proc/mounts

# 当前挂载进去的内容
grep -E '<transitionPoint>|<minimumLux>' /product/etc/displayconfig/display_id_*.xml
```

## 卸载 / 回滚

```sh
# 立即摘掉挂载（不用重启；重启后本来也会自动失效）
sh /data/adb/modules/mi14_screen_enhance/uninstall.sh

# 或者：管理器里停用 / 卸载模块，然后重启
```

bind mount 只存在于内存，**不修改系统分区**，重启后不挂载即等同原厂。

## 兼容性

* 机型：**小米14 / houji / 23127PN0CC**（HyperOS，Android 16 实测）
* Root：KernelSU 3.3.0 实测通过；Magisk 理论可用（安装脚本双兼容）
* 非 houji 设备上开机脚本会**自行跳过**，不做任何改动

## 不做什么（有意为之）

| 项 | 原因 |
|---|---|
| 不改最低亮度 | 由 framework 资源 `config_screenBrightnessSettingMinimumFloat` 决定，displayconfig 碰不到；RRO 也被平台权限挡住（见上文） |
| 不改 `screenBrightnessMap` | 那是面板标定。自动亮度是「环境光 → 目标 nits → backlight」两步换算，改 nits 列会让自动亮度整体算错 |
| 不改 `sdrHdrRatioMap` | HDR 亮度走 `getHdrBrightnessFromSdr()`，**与 `transitionPoint` 无关**，本次不需要动，也就不会削弱 HDR |
| 不改热控配置 | `thermal_brightness_control.xml` 等是小米的热控兜底。留着它，机器变热时高亮度会被自动压回来，这是**安全网** |
| 不改 `dolby_vision.cfg` | 参考模块那份里的 PWM 表 / 亮度表 / gamma / 色域坐标全是 K90（annibale，3500 nits 面板）的标定，搬到 houji 上是错的 |
| 不随包分发小米文件 | 原厂 `displayconfig` 版权属小米；改为开机从设备自身派生 |

## 版权与许可

```
Copyright (c) 2026 bingjiling92
SPDX-License-Identifier: MIT
```

本项目以 MIT License 发布。你可以自由使用、修改、再分发，但需保留上述版权声明与许可声明。

`THIRD-PARTY-NOTICES.md` 中保留了参考项目 K90ScreenEnhance（MIT，Copyright (c) 2024 Sc）
的许可声明。本仓库未包含该项目的任何文件或代码。

## 致谢

* **K90ScreenEnhance**（Clouditer / Sc，MIT）—— 提供了「用 bind mount 覆盖 `displayconfig`
  的 `transitionPoint`」这一思路。
* **AOSP**（Apache-2.0）—— `DisplayDeviceConfig` / `HighBrightnessModeController`
  的源码是确认机制的依据。

## 免责声明

修改系统显示配置属于**非官方行为**。本模块仅改变软件层的亮度上限，不改变面板硬件能力，
但更高的亮度会带来**更明显的发热与耗电**，长期高亮度对 OLED 寿命不利。

模块内置多重校验（目标值合法性、标签完整性、行数一致性），任何一项不过即**拒绝挂载**
并保持原厂行为；但仍请自行评估风险。作者不对任何直接或间接损失负责。

---

## English

**mi14_screen_enhance** — a KernelSU/Magisk module that raises the *base* brightness ceiling
of the Xiaomi 14 (houji / 23127PN0CC).

On stock firmware the panel is capped at **500 nits** whenever HBM / sunlight mode is not
engaged — even with the slider at 100%. That cap is `mHbmData.transitionPoint`
(`0.499938`) in `HighBrightnessModeController.getCurrentBrightnessMax()`.

This module raises it to **1400 nits** (`0.952386766`, default) or **1000 nits**
(`0.808082041`, `balanced` profile), verified on-device.

The module derives the patched `displayconfig` **at boot from the device's own stock file** —
no Xiaomi proprietary file is redistributed. It only ever touches the two tags
`<transitionPoint>` and (optional) `<minimumLux>`.

**The minimum brightness is NOT adjustable by this module**: it comes from the framework
resource `android:dimen/config_screenBrightnessSettingMinimumFloat`, read by
`loadBrightnessConstraintsFromConfigXml()` (which takes no XML input). Only an RRO can
change it. As a workaround, Android's built-in *Reduce bright colors* goes below the
hardware minimum — see the section above.

**Copyright (c) 2026 bingjiling92 — MIT License.** See [LICENSE](LICENSE).
