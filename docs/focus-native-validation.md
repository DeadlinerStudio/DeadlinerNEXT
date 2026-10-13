# 鸿蒙专注原生对齐验证

日期：2026-10-12。范围：Task / Habit 专注、联合结束、历史、系统提醒和现有统计三页签；不包含总览看板。本轮未修改或部署 Android。

## 实现边界

- ArkTS 通过 KMP state / typed target / command / focus overview 投影读取规则和统计，不自行持久化有效时间或推算习惯数量。
- Task/Habit 入口复用原生列表与 Sheet；数量确认冻结 session UID、启动日、习惯版本。到点不自动打卡，确认入口保留，可对保存结果补打卡。
- 活动会话优先；旧通知每次刷新显式按 UID 投影，不广播只读 selection revision。不存在/已删除的旧通知不显示其他会话的打卡上下文。
- Task 状态变更/删除、Habit 归档/删除包括批量入口，先检查当前计时并提示去时钟解决，再由用户重试。批删确认提交前再检查，避免部分批量操作。
- 系统提醒使用 ReminderAgent 实际返回 ID 取消，进程恢复通过系统提醒列表清理本功能所有权范围；相同 session 去重。权限失败提示用户，不回滚已经保存的计时。
- 现有概览、趋势、上月三页签追加专注数据；使用既有 @ohos/mpchart，不实施新的看板或指标子页签。

## MiniBar 兼容

[HdsTabs 官方参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs) 已通过 Harmony developer knowledge MCP 核实：MiniBar 起始 API23，barLayoutMode / HdsBarLayoutMode 起始 API24。

- API23 + 新浮动 UI：HdsTabs 的 barFloatingStyle.miniBar，仅传 miniBarBuilder，保持系统水平排列。
- API24+ + 新浮动 UI：同一原生 MiniBar，加 HdsBarLayoutMode.VERTICAL。
- 无活动/暂停会话时不设置 miniBar 属性，真实不占位。
- API20～22 或关闭新浮动 UI：全局宿主旧布局安全回退，入口不只限首页。
- runtime 比较统一使用 distributionOSApiVersion（60100 / 60101），不混用 SDK API 与发行 OS 版本。Available 注解按当前编译器签名使用 '23' / '24'。

## 可重复检查

```sh
node scripts/check_focus_native_contract.mjs
python3 scripts/check_large_core_files.py --repo entry/src/main/ets --suffix-file core_suffixes.txt --threshold 1000
git diff --check
```

- `check_focus_native_contract.mjs` 要求 Node25+；本轮 Node25.8.1，18 项通过。15 项在宿主执行实际 repository / 元数据对比代码，但 native bridge、AppStorage、ReminderAgent 使用 mock；另 3 项仅检查 MiniBar 源码合同。这不是 ArkTS 运行时或设备验收。
- 格式与 Outcome 文案辅助函数 9 个断言宿主通过；已增加并注册 FocusPresentation Hypium suite，未在设备运行 Hypium。
- 本轮新增/修改 ETS 未超过 1000 有效行；旧 SearchPage1103 / DatabaseHelper1084 的既有规模问题未扩大治理范围。
- diff 空白检查通过。仓库已有其他用户未提交修改，未 reset 或批量回退。

## 构建证据

构建显式设置 DEVECO_HOME、DEVECO_SDK_HOME、JAVA_HOME、DEADLINER_GRADLE_JAVA_HOME；仓库 prebuild 只构建/部署鸿蒙 Core（--skip-ios --skip-android）。未修改构建基础设施。

- 初次完整构建：Core release 与 NAPI 编译通过，ArkTS 报回调 void 返回 Promise 和 Available 注解版本格式错误；已修正。日志 `/private/tmp/harmony-focus-build.log`。
- 第二次构建：Core release、C++/NAPI、ArkTS 与 PackageHap 通过，SignHap 报 11014003 / HmacPBESHA256 算法环境错误；日志 `/private/tmp/harmony-focus-build-final.log`。
- 最终构建：正确的 DevEco JDK25 JAVA_HOME 和 PATH 下，完整 assembleHap / SignHap 通过，BUILD SUCCESSFUL in 2 min 47 s 608 ms。日志 `/private/tmp/harmony-focus-build-java25.log`。
- 新签名产物：`entry/build/default/outputs/default/entry-default-signed.hap`，2026-10-12 13:52:45，37,608,318 字节；SHA256 `1c38ccd0f8899d5a3c153b0f2c4886707911cd6274cd87daac06afb5f136d828`。Unsigned HAP 同轮 13:52:44，37,299,794 字节。

签名环境修复：原构建 JAVA_HOME 指向 Studio jbr 根目录，正确嵌入 JDK 为 `/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`。由于官方签名工具执行 PATH 中的 `java`，最终构建同时显式前置该 JDK 的 bin；这样签名成功。仅修正本次进程环境，未改用户 keystore、密码、签名配置、全局 JDK 设置或构建基础设施。Core 专用 Gradle JDK 保持21。

[ReminderAgent 官方接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-reminderagentmanager) 静态确认取消须使用实际 reminderId，callback 成功 err 为 undefined，1700003 为提醒不存在。其他失败保留句柄重试，真实系统投递仍未验收。

## 尚未设备验收

`hdc list targets` 返回 `[Empty]`。以下仍需有设备后验收，不以源码检查或编译通过替代：

- API23 单行与 API24 双行真实排布、横屏/大字/长标题、深浅色与 Tab 遮挡。
- 暂停/继续按钮点击不会误触打开 Sheet；每个 Tab 上的当前会话入口。
- 后台/杀进程到点提醒投递、权限拒绝提示、通知点击和进程恢复。
- 数量输入期间到点/跨午夜、元数据改变、新旧会话竞态的端到端交互。
- 统计更新与图表的真实渲染、辅助功能读屏。
