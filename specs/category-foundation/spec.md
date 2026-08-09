# 分类功能 UI 基座

## 背景

- 创建日期：2026-08-04
- 功能标识：`category-foundation`
- 需求来源：主页需要接入 KMP 共享分类，并以左上角入口展开分类侧边栏完成多选筛选。

## 目标

- 将 KMP `Category`（含预设分类）以只读 JSON ABI 暴露给 HarmonyOS；ArkTS 不维护第二套分类真相。
- 任务适配模型保留 `categoryUid`，在主任务列表中展示分类名称和颜色标记。
- 分类侧边栏位于根页面 `HdsTabs` 外层；主页左上角按钮展开 `SideBarContainer`，用户可多选分类，列表仅显示命中任一所选分类的任务。
- 分类使用跨平台 `icon_semantic_id`；HarmonyOS 仅在渲染时映射为系统 Symbol，未知键降级为 `bookmark`。
- 侧边栏显示来自 KMP 的预设分类与已存在分类；本批不提供分类创建、编辑、删除或任务分类赋值入口。

## 非目标

- 不修改分类的 KMP 领域模型、预设集合、同步语义或 iOS 已有调用语义。
- 不实现“新增分类”的可用操作，仅为后续入口预留视觉位置。
- 不实现习惯分类筛选、分类管理页、分类排序或筛选条件持久化。

## 用户场景

1. 用户在主页任务页点击左上角分类按钮，展开侧边栏并看到 KMP 提供的“工作、学习、生活”等预设分类，以及已同步的非预设分类。
2. 用户选择“工作”和“学习”后，主页仅显示 `categoryUid` 为其中任一分类的任务；再次取消所有选择后恢复全部任务。
3. KMP 同步带来的任务分类可在任务卡片上显示分类名称与颜色，未知或已删除分类不会导致页面失败。

## 验收标准

- KMP C ABI 提供只读分类目录 JSON，结果包含预设分类与未删除的持久化分类；ArkTS 通过 NAPI 消费该结果。
- 任务 DTO 映射保留 `categoryUid`；任务卡片可显示其目录中匹配到的分类名称和颜色。
- 左上角按钮可展开/收起分类侧边栏；侧边栏分类项支持多选，筛选结果在任务列表中立即可见。
- 预设分类至少显示 KMP `CategoryPresets.all` 中定义的八项；无分类任务在任一筛选启用时不显示。
- “新建分类”入口为明确的禁用占位，不产生本地或 KMP 写入。

## 风险与约束

- 当前发布的 `libDeadlinerCore.so` 未导出分类目录 RPC；本批需在相邻 KMP Core 仓库增加只读 ABI、重新构建并复制本仓库依赖的 native library。
- 原生 `SideBarContainer` 使用 `SideBarContainerType.Overlay`；分类 `HdsNavigation` 与主页 `AdaptedHdsTabs` 作为其两个直接子组件，内容根 `Stack` 显式扩展上下系统安全区。`showSideBar` 使用 `$$` 双向绑定，以采用框架默认动画并在手势收起后同步状态；主页展开入口和分类导航栏的收起入口均通过 260ms `animateTo` 更新该状态。分类导航栏通过 `title` 与 `menu` 提供独立收起按钮；展开时由原生容器处理内容遮罩，并隐藏主页展开按钮。
- 分类图标遵循飞书《分类图标原语》的 HarmonyOS 映射；当前 SDK 未提供 `cart_mirroring`，该非预设项暂安全降级为 `cart`。
- KMP 分类数据是唯一业务来源；ArkTS 仅作 DTO、缓存和展示投影，不能硬编码预设分类。
- 本批为跨仓库契约增量，最终应在 KMP Core 与 HarmonyOS 分别验证 native bridge 和 HAP 编译。

## 实现结果

- KMP Core bridge 升级至 v9，新增只读 `deadliner_persistence_category_catalog_json`：结果合并 `CategoryPresets.all` 与未删除的持久化分类，且不产生分类写入。
- HarmonyOS NAPI、ArkTS declaration、KMP adapter 与只读分类仓储已接入该 ABI；任务适配保留 `categoryUid`。
- 根页面通过 Huawei `SideBarContainer` 在 `AdaptedHdsTabs` 外层承载分类 `HdsNavigation`，使用 `Overlay` 类型。主页左上角的 `close_sidebar` 图标用于展开；侧栏导航栏的标题为“分类”，其 `menu` 使用 `open_sidebar` 图标收起。侧栏内容使用 `background_secondary`，只保留分类列表与禁用的“新建分类”占位；原生容器提供遮罩、动画和手势同步，展开时主页按钮同步隐藏；分类可多选，任务卡片显示名称、图标和颜色。
- 任务卡片保持原有 76vp 高度；分类信息与备注共享辅助行，避免改变主页列表密度。
- KMP 预设分类的 `iconKey` 已迁移为语义键；HarmonyOS 使用 `CategoryIconResolver` 映射 36 个已整理的图标原语，并兼容旧的 iOS SF Symbol 值。
- “新建分类”仅显示禁用占位。宽屏布局、习惯分类筛选、分类管理和任务分类写入留待 iOS 原语总结后实施。
