# Colorful Tab Brand Scope Module Plan

## 模块拆分

- `contract`：在 `HdsTabsCustomization` 中为 Tab 描述补充完整品牌色对，作为各 Tab 视觉身份的数据源。
- `domain`：在 `ThemeManager` 中提供纯函数式 scoped theme 解析，决定多彩/非多彩主题的覆盖规则。
- `presentation-scope`：在 `Index` 的每个 `TabContent` 内建立局部 ArkUI 主题作用域，并把 scoped `ITheme` 传给一级页面。
- `presentation-pages`：清单、概览、灵感、AI、我的及其一级专属子组件显式消费 scoped `ITheme`。
- `presentation-atmosphere`：顶部氛围层消费外部解析后的 Tab 主题，移除颜色资源硬编码。
- `resources`：为五个 `module_*` 品牌色补齐浅色和深色 `*_50` 资源。

## 平台映射

- iOS：本次不修改；需求仅针对当前 HarmonyOS 的 `ThemeManager` 与 HDS Tabs 实现。
- HarmonyOS：`common/theme` 承担解析规则，`model/HdsTabsCustomization.ets` 提供 Tab 色数据，`pages/Index.ets` 建立页面作用域，`pages/routes/*` 消费主题。
- Android：本次不修改；若未来同步，应采用 Compose 局部 `MaterialTheme`/CompositionLocal，而不是切换全局主题。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 不新建巨型主题文件；局部作用域组件单独放入 `pages/components`。
- `Index.ets` 已承担主容器职责，只增加主题解析和作用域接入，不搬入页面具体配色规则。
- 对同时作为 Tab 与 Navigation destination 的 `CapturePage` 保留显式基础主题入口。

## 风险点

- ArkUI `WithTheme` 只影响系统/HDS 主题读取，自定义组件仍需显式传递 `ITheme`。
- 直接修改全局 `currentTheme` 会造成二级页面泄漏和 Tab 转场串色，禁止采用。
- 多层 Section 中已有 `@StorageProp('currentTheme')`，只迁移一级页面实际使用 brand 的组件，避免无关状态管理重构。
- `brand50` 必须跟随深浅色资源，否则暗色模式会出现错误透明底色。
- 局部主题不能包裹整个 `Navigation`，否则 push 出的二级页面可能继承 Tab 色。

## 最终实现映射

- `ThemeModel.ets`：新增 `TabBrandPalette`。
- `ThemeManager.ets`：新增 `resolveRootTheme`，仅在 `colorful` 下覆盖 `brand`、`brand50`、`tabIcon`。
- `HdsTabsCustomization.ets`：五个 Tab 统一提供 `brandPalette`。
- `RootTabThemeScope.ets`：使用 `WithTheme` 为单个一级页面设置 HDS/系统组件主题。
- `Index.ets`：TabBar、五个 TabContent 和顶部氛围层统一从 `resolveRootTheme` 取色。
- 一级页面：Main、Overview、Capture、AI、User 及必要的 root-only 子组件显式传递 scoped `ITheme`。
- Navigation destination：Overview、Capture、AI 通过 `isNavDestination` 使用基础主题。
