# 第三方声明 / Third-Party Notices

## K90ScreenEnhance

本项目的**思路**参考了 `K90ScreenEnhance`（作者 Clouditer）：
即通过覆盖 `displayconfig` 里的 `<transitionPoint>` 来改变屏幕亮度天花板。

**本项目没有包含该模块的任何文件或代码。** K90 模块携带的两个 payload
（`dolby_vision.cfg` 与 `display_id_4630947238302509459.xml`）是 Redmi K90
（annibale，3500 nits 面板）的专属标定，对小米14 不适用，因此本仓库一份也没有采用。
本项目的 `post-fs-data.sh` / 各脚本均为独立编写。

该模块以 MIT 许可发布，其声明如下，特此保留：

```
MIT License

Copyright (c) 2024 Sc

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 关于小米原厂文件

本仓库**不包含任何小米（Xiaomi）原厂文件**。

模块在开机时读取设备自身的
`/product|/vendor/etc/displayconfig/display_id_<ID>.xml`
（该文件的版权属于小米，不随本仓库分发），只在内存/`/data` 中派生出一份改写版用于
`mount --bind`，不写回系统分区、不修改原文件。

## 参考的 AOSP 源码

为确认机制而阅读的 AOSP 源码（Apache-2.0），仅用于分析，未在本项目中使用其代码：

* `frameworks/base/services/core/java/com/android/server/display/DisplayDeviceConfig.java`
* `frameworks/base/services/core/java/com/android/server/display/HighBrightnessModeController.java`
* `frameworks/base/services/core/java/com/android/server/display/DisplayPowerController.java`
