# Colorful Tab Brand Scope

## 背景

- 创建日期：2026-08-10
- 功能标识：`colorful-tab-brand-scope`
- 需求来源：统一管理多彩主题，并让每个主 Tab 的一级界面使用该 Tab 对应的品牌色。

## 目标

- 保留 `currentTheme` 作为全局基础主题，不因主 Tab 切换而改变。
- 由 `ThemeManager` 统一派生主 Tab 一级页面主题。
- 多彩主题下，清单、概览、灵感、AI、我的分别使用自己的 `brand`、`brand50` 和 Tab 选中色。
- 非多彩主题下保持现有主题行为。
- TabBar、一级页面自定义组件、HDS/系统组件与顶部氛围层使用同一份 Tab 主题来源。

## 非目标

- 不改变图表、任务状态和 Indicator 语义色。
- 不让 Tab 品牌色进入搜索、详情、编辑、设置、帮助等二级页面。
- 不改变主题偏好持久化格式，也不持久化当前 Tab 的派生主题。
- 不调整 Tab 顺序、隐藏能力或页面业务逻辑。

## 用户场景

1. 用户选择“多彩”主题后，在五个主 Tab 之间切换，各一级页面的主要交互色与当前 Tab 色一致。
2. 用户通过滑动或点击切换 Tab 时，离场与入场页面不会因为共享全局品牌色而串色。
3. 用户从一级页面进入二级页面时，二级页面继续使用基础主题品牌色。
4. 用户切换到非多彩主题时，所有主 Tab 恢复该主题统一的品牌色和 Tab 图标色。

## 验收标准

- 多彩主题的 Tab 映射：清单 `module_list`、概览 `module_overview`、灵感 `module_capture`、AI `module_ai`、我的 `module_user`。
- 每个映射必须同时提供浅色和深色的半透明 `brand50` 资源。
- `ThemeManager` 是“何时采用 Tab 品牌色”的唯一策略入口；页面不得新增 `currentThemeKey === 'colorful'` 分支。
- `SemanticTopAtmosphere` 不再重复维护各 Tab 颜色映射；清单的 danger/warning/success 状态氛围规则继续保留。
- `currentTheme` 和应用级 `ThemeControl` 继续表示基础主题，避免污染 Navigation 二级页面。
- 每个 `TabContent` 使用局部 ArkUI 主题作用域，让 HDS/系统组件读取同一 scoped brand。
- 自定义组件通过显式 `ITheme` 参数接收一级页面主题；Navigation destination 使用基础主题。
- Tab 重排、隐藏、手机/宽屏布局、浅色/深色模式下结果一致。
- HarmonyOS 编译必须显式设置 `DEVECO_HOME`。

## 风险与约束

- `WithTheme` 只包裹单个 `TabContent` 的一级页面，不包裹根 `Navigation`。
- Navigation destination 复用的 Overview、Capture、AI 页面必须根据 `isNavDestination` 回退到基础 `currentTheme`。
- 工作区已有其他未提交改动，本功能不创建保护提交，也不改写无关文件。
- 当前大文件扫描包含三方依赖和既有 `SearchPage.ets`、`DatabaseHelper.ets` 超限项；本功能没有新增或修改这些超限文件。
- 构建中的依赖资源冲突、第三方 ArkTS 严格类型警告和既有 deprecated/API 兼容警告不属于本功能范围。
