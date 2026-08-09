# HdsTabs 底栏自定义 Module Plan

## 模块拆分

- `contract/domain`：`model/HdsTabsCustomization.ets` 定义标签 ID、标签元数据（含模块色）、默认值、配置归一化、图标资源选择和“可见/隐藏标签”计算。
- `infra`：`SettingsConstants` 增加三个 Preferences 键；`LocalValues` 在启动时加载、归一化并提供顺序/可见性/渲染策略写入方法。
- `presentation-settings`：`HdsTabsCustomizationSettings.ets` 提供二级设置页、拖拽排序、开关、策略单选和恢复默认。
- `presentation-root`：`Index.ets` 根据 AppStorage 生成排序后的 `TabContent`，并向 SymbolGlyph 注入所选渲染策略。
- `presentation-user`：`UserPage.ets` 在归档管理卡内按隐藏状态生成快捷入口；概览、灵感、AI 页面各自的 Destination builder 提供独立路由。底栏渲染保留 `HdsNavigation`，快捷路由改为页面自身的 `HdsNavDestination`。

## 平台映射

- iOS：`Features/Settings/RichTabCustomizationSettingsView.swift` 作为交互与文案参考；iOS 的 `RichTabCustomization` 负责顺序与隐藏状态。
- HarmonyOS：`entry/src/main/ets/model`、`common/local`、`pages/routes/user/settings` 与根 `pages/Index.ets`。
- Android：本次不改动；仅记录交互对齐点，不引入跨端共享代码。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 将配置规则保留在独立模型文件；设置页不承载根标签页业务；根页只负责将已归一化配置映射为 HdsTabs 内容。

## 风险点

- 动态标签数量会改变 HdsTabs 的 position index，需要根页监听并修正当前索引。
- 拖拽 API 需要 `ListItem` 与稳定 key；固定标签仍可排序但不可隐藏。
- `SINGLE` 只适用于 SymbolGlyph，AI 与灵感的图片资源不应被错误转换为系统符号。
- 隐藏入口数量加上归档和使用手册超过 3 时，需要保持横向滚动区域的固定入口宽度，防止条目挤压或不可点击。

## 实现回写

- 配置模型与应用内持久化按计划拆分；未引入跨端或全局状态迁移。
- 设置页使用 `ListItem` + `ForEach.onMove` 提供长按拖拽，重置操作同时恢复三项配置。
- 根页面不再维护固定标签数组，而是从配置模型取得可见标签；`AdaptedHdsTabs` 保持原有跨设备布局职责，不作修改。
- 本次最大新增核心代码文件为 `HdsTabsCustomizationSettings.ets`，远低于 1000 行阈值。
