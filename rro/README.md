# 最低亮度 RRO 工程

把 framework-res 里决定「最低亮度」的两个资源覆盖掉，从而真正把亮度下限压下去。

> 主模块 `mi14_screen_enhance` **改不了最低亮度**——原因见主 README 的「关于最低亮度」。

---

## ⚠️ 先说结论：在当前这台 ROM 上，这条路走不通

**不是没做对，是平台不允许。** 已经在真机上把 APK 编出来、签名、装上了，结果：

| 步骤 | 结果 |
|---|---|
| `aapt2 link` + 签名 + `pm install` | ✅ 装得上（需声明 `android:targetName`，见下） |
| `cmd overlay enable` | ✅ 启用成功，但状态是 `STATE_NO_IDMAP` |
| `idmap2 create` | ❌ **`no resources were overlaid -> failed to create idmap`** |
| 覆盖是否生效 | ❌ 否。`cmd overlay lookup android:dimen/config_screenBrightnessSettingMinimumFloat` 仍是原值 `8.54597E-4` |

原因（两条独立证据）：

1. 平台的扫描规则是：**覆盖 `android` 的 overlay，必须与目标同签名，或者声明
   `<overlay android:targetName="...">` 指名一个 overlayable。**
   实测：不加 `targetName` 时 `pm install` 直接失败：

   ```
   Scanning Failed.: Overlay com.bingjiling92.mi14.dimfloor and target android signed
   with different certificates, and the overlay lacks <overlay android:targetName>
   ```

   加上 `targetName`（**任意字符串**，连 `BOGUSNAME` 都行）就能装进 —— 说明名字本身
   在扫描阶段不校验，真正的限制在下一步。

2. 真正的限制是：**framework-res 一个具名 overlayable 都没有。**
   解析 `/system/framework/framework-res.apk` 的 `resources.arsc`，包内 chunk 只有：

   ```
   0x0201 TYPE               x465
   0x0202 TYPE_SPEC          x48
   0x0206 STAGED_ALIAS       x1
   （没有 0x0204 OVERLAYABLE，也没有 0x0205 OVERLAYABLE_POLICY）
   ```

   没有 overlayable ⇒ 非平台签名的 overlay **无法映射其中任何资源**，
   `idmap2` 只能给出 `no resources were overlaid`。
   而平台私钥不在设备上（ROM 只带平台证书，不带私钥）。

**所以：本工程只有在「拿到平台签名」或「换一个声明了 overlayable 的 ROM」时才有用。**
产物与完整构建链保留在这里，未来条件满足时可以直接用。

---

## 现在想更暗怎么办

用系统自带的「**极暗 / Reduce bright colors**」——它用色彩变换把亮度压到硬件下限**以下**，
这正是「还能更暗」这件事：

```sh
settings put secure reduce_bright_colors_activated 1     # 开启
settings put secure reduce_bright_colors_level 100       # 强度，越大越暗
settings put secure reduce_bright_colors_activated 0     # 关闭
```

或直接用快捷设置里的「极暗」磁贴。

> 补充：框架下限 `8.54597E-4` 对应的面板原始背光是 `25 / 4095`，
> 硬件本身确实还有往下余量 —— 只是那部分被平台权限挡住了。

---

## 它覆盖什么

| 资源 | 原厂值 | 本工程值 |
|---|---|---|
| `android:dimen/config_screenBrightnessSettingMinimumFloat` | `0.000854597` | **`0.0002`** |
| `android:dimen/config_screenBrightnessDimFloat` | `0.000854597` | **`0.0002`** |

这两个值由 `DisplayDeviceConfig.loadBrightnessConstraintsFromConfigXml()` 读入
`mBacklightMinimum` / `mBrightnessDim`（`dumpsys display` 里就是
`mBacklightMinimum=8.54597E-4`）。改 `res/values/dimens.xml` 里的数字即可，越小越暗。

## 关键实现细节（踩过的坑）

1. **必须用 `<item type="dimen" format="float">`，不能用 `<dimen>`。**
   原厂这两个资源在 APK 里以 **TYPE_FLOAT (0x04)** 存储（可在
   `AospFrameworkResOverlay.apk` 的 `resources.arsc` 中验证：Res_value =
   `08 00 04 00 09 07 60 3a`，即 float 0.000854597）。写 `0.0002dp` 会编成 packed
   dimen(0x05)，与目标类型不符会被 idmap2 丢弃。

2. **`android:targetName` 必须有**（否则 `pm install` 阶段就被拒）。
   如果是平台签名，不需要它；如果目标 ROM 声明了 overlayable，这里要写**真实的
   overlayable 名**。当前默认值仅用于通过扫描阶段。

3. **`android:isStatic`**：见 `AndroidManifest.xml` 注释。默认 `false`（需模块
   `cmd overlay enable`，丢 APK 后第二次重启生效）；改 `true` 可一次重启生效。

## 构建

### 方案 A：手机 Termux 里直接编（不需要电脑，实测可用）

```sh
# Termux 里
pkg install aapt2 apksigner zipalign openjdk-17
bash build-termux.sh          # 产出 mi14_dimfloor.apk
```

### 方案 B：本机（沙箱/真机）无 Java 构建（本工程实际用的方式）

Termux 的 `apksigner` 是 Java 程序，而本机 Termux 的 JVM 会被小米的
`/system_ext/lib64/libjpeg-hyper.so` 带崩（`dlopen failed: cannot locate symbol
"jsimd_huff_encode_one_block"`）。所以改成 `openssl` + 纯 Python 手写 JAR(v1) 签名：

```sh
# 1) 编译 + 对齐（Termux 的 aapt2/zipalign，但用一个「旧格式」的 android.jar：
#    本机 Android 16 的 resources.arsc 太新，aapt2 会报 illegal map type）
sh build-phone.sh /path/to/rro

# 2) 签名（openssl + python，不需要 Java）
sh sign-apk.sh /path/to/rro
```

要点：

* `aapt2 link -I` 需要一份**旧格式** android.jar。Termux 自带的（Android 16）
  解析不了，用 Robolectric 的 `android-all`（如 API 28）即可：
  ```sh
  curl -L -o android-all-9.jar \
    https://repo1.maven.org/maven2/org/robolectric/android-all/9-robolectric-4913185-2/android-all-9-robolectric-4913185-2.jar
  ```
  （框架属性 ID 跨版本稳定，旧 jar 编出来的 manifest 在新系统上一样有效。）
* 用 `--target-sdk-version 29`：Android 只对 `targetSdkVersion >= 30` 强制 v2 签名，
  targetSdk 29 时 **v1(JAR) 签名即可**被 PackageManager 接受（实测 `pm install` 成功）。
* v1 摘要覆盖的是解压后内容，所以「先 zipalign 后签名」是安全的。

### 方案 C：电脑上用 Android SDK

```sh
ANDROID_SDK_ROOT=~/Android/Sdk bash build.sh   # 需要 build-tools 与 JDK
```

## 部署（前提：平台签名或目标 ROM 有 overlayable）

```sh
mkdir -p /data/adb/mi14_screen_enhance/rro
cp mi14_dimfloor.apk /data/adb/mi14_screen_enhance/rro/
# 重启：主模块会把它挂到 /product/overlay/ 并执行 cmd overlay enable
```

## 验证

```sh
cmd overlay list | grep -i dimfloor                 # 期望 [x]
dumpsys overlay | grep -A12 'com.bingjiling92.mi14.dimfloor:0' | grep mState
                                                    # 期望 STATE_ENABLED，不是 STATE_NO_IDMAP
dumpsys display | grep -o 'mBacklightMinimum=[0-9.E-]*'
                                                    # 期望变成你设的值，而不是 8.54597E-4
```

## 回滚

```sh
cmd overlay disable --user 0 com.bingjiling92.mi14.dimfloor
rm -f /data/adb/mi14_screen_enhance/rro/mi14_dimfloor.apk   # 然后重启
```

---

**Copyright (c) 2026 bingjiling92 — MIT License**
