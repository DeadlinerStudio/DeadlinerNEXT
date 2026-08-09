# 分类功能 UI 基座 Module Plan

## 模块拆分

- `kmp-category-contract`：在 KMP `ohosArm64` C ABI 中只读导出分类目录；目录由 `CategoryPresets.all` 和未删除的持久化分类组成。
- `ohos-category-infra`：NAPI 动态符号绑定、ArkTS native declaration、`KmpCategoryRepositoryAdapter` 与只读 `CategoryRepository`。
- `ohos-category-presentation`：可复用 `CategoryFilterSideBar`、以原生 `SideBarContainer` 包裹分类 `HdsNavigation` 与 `AdaptedHdsTabs` 的根页面容器、侧栏显隐/遮罩状态、`CategoryIconResolver`，以及任务卡片的紧凑分类标签。
- `ohos-task-filter`：任务列表把选择的分类 UID 作为 UI 参数应用；KMP 保持任务查询与分类 UID 的事实来源。

## 平台映射

- iOS：不改动；后续以其分类原语总结校准交互与分类管理能力。
- HarmonyOS：KMP Core `shared/src/ohosArm64Main/.../DeadlinerPersistenceCApi.kt` 新增只读导出；本仓库的 `entry/src/main/cpp/`、`common/kmp/`、`common/repository/` 和 `pages/` 消费并展示。
- Android：不改动；KMP `Category` 领域模型与预设集合保持跨端共享。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 分类 DTO/adapter/仓储/侧边栏组件各自独立，避免向 `MainHomePage.ets` 或 `TaskListSection.ets` 堆叠业务解析。

## 风险点

- Native library、NAPI 和 ArkTS declaration 必须作为同一 ABI 批次更新；缺少任一层时不允许调用新符号。
- 侧边栏由根页面承载，因此始终位于 `HdsTabs` 外层；目前仍仅由手机主页的现有左上角入口触发展开，分类面板内可独立收起。
- 分类图标以跨平台语义键存储；HarmonyOS 不依赖 iOS SF Symbol，历史 iOS 图标值仅作为展示兼容输入。
- 同步后的分类变化在下一次任务刷新时重新解析；本批不新增分类列表的独立实时订阅。
