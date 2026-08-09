# HarmonyOS 全量分类功能 Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 产品确认：保留搜索页，管理进入 SideBar

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构
- [x] 扩展 KMP 分类命令、习惯/Deadline 原子分类写入与 OHOS C ABI
- [x] 扩展 NAPI、ArkTS persistence service 和可写 `CategoryRepository`
- [x] 扩展任务/习惯 ArkTS 投影的 `categoryUid`

## 阶段 3：功能实现

- [x] 接入任务与习惯编辑器的共享分类选择器和快速新建
- [x] 接入首页 SideBar 的全部/未分类/多选筛选
- [x] 在 SideBar 增加分类管理模式与软删除确认
- [x] 接入任务/习惯卡片分类投影和刷新
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 验证记录

- 2026-08-05：`:shared:publishDebugOhosLibraryToDeadliner` 成功，KMP OHOS 库包含分类 CRUD 和习惯分类同步 ABI。
- 2026-08-05：使用显式 `DEVECO_HOME` 执行 `assembleHap`，BUILD SUCCESSFUL。
- 2026-08-05：预设分类占位记录修复重新发布 KMP 库后，再次执行 `assembleHap`，BUILD SUCCESSFUL。
- 2026-08-05：修复新增分类 ABI 被错误纳入持久化桥全局加载门槛的问题；执行 `clean` 后重新构建 HAP，BUILD SUCCESSFUL。
- 2026-08-06：定位到 `debugShared` Kotlin/Native 运行时存在未解析的 ObjC 符号，发布任务改为打包 `releaseShared`；重新构建的 signed HAP 内分类 ABI 完整且无未解析 Kotlin 符号，`assembleHap` 成功。
- 2026-08-06：分类 SideBar 改为 `TopSafeContainer` + 官方 `List`/`HdsListItem` 组合，底部入口改为“添加分类”，分类项支持左滑编辑、非预设项左滑删除；未分类筛选兼容历史空字符串分类值，`assembleHap` 成功。
- 2026-08-06：修复预设分类只在目录中合并、却没有数据库外键行的问题；KMP 在任务或习惯首次引用预设分类时自动物化对应记录，避免任务/习惯添加或编辑保存时的 `SQLITE_CONSTRAINT FOREIGN KEY`，重新构建 release Core 和 signed HAP 成功。
- 2026-08-06：侧栏改为透明内容层与外层 `COMPONENT_REGULAR` 模糊；“全部”严格独占，具体分类和“未分类”可组合多选；点击改为 `HdsListItemCard.onClick`，所有分类项支持横滑编辑和删除；底部添加入口改为品牌色沉浸光感按钮，`assembleHap` 成功。
- 2026-08-06：将添加按钮接入 `ImmersiveMaterial` 的品牌色交互光效；分类筛选点击改为自定义行的直接点击面，避开 HDS 横滑容器的点击拦截；横滑编辑图标改为主题品牌色，`assembleHap` 成功。
- 2026-08-06：分类侧栏三类项统一为 `CategoryFilter` 驱动的受控 `HdsListItem.isSelected`，并清空 HDS 内建选中底色；“全部”只在全量状态选中，未分类可与具体分类组合选中，`assembleHap` 成功。
- 2026-08-06：修复 ArkUI 对 `@Link` 类实例深层字段不稳定触发重绘的问题：侧栏用本地 `@State` 保存具体分类与未分类的选中态，并在每次变更时同步写回 `CategoryFilter`；筛选业务与选中 UI 均可立即更新，`assembleHap` 成功。
- 2026-08-06：针对 HDS 自定义列表内容未随受控状态重新投射的问题，全部与未分类项在状态切换时按分支重新创建，分类项将选中态纳入稳定行 key；选中圆角和勾选图标可与筛选状态同步，`assembleHap` 成功。
- 2026-08-06：修复分类 CRUD C ABI 的双调用问题：NAPI 先探测 JSON 长度、再写入缓冲区时，KMP 会复用第一次写操作的响应而非再次执行新增/删除；重新发布 release Core 并执行 `assembleHap` 成功。
- 2026-08-07：分类编辑器可选项同步 iOS 原语：36 个语义图标和 20 个 `color_token`→HEX 调色板集中定义；当前 HarmonyOS SDK 不包含 `cart_mirroring`，购物分类使用编译可用的 `cart` 兼容符号，`assembleHap` 成功。
- 2026-08-09：分类编辑 Sheet 统一为原生标题与关闭按钮、透明模糊背景和 `FIT_CONTENT`/`MEDIUM`/`LARGE` 多档 detents；编辑内容去除重复标题，保存按钮接入主题品牌色沉浸光感，`assembleHap` 成功。
- 2026-08-09：添加页分类字段和分类选择 Sheet 统一为 16 圆角；选择 Sheet 使用原生标题/关闭按钮与多档 detents，未分类选中态和新建分类入口均适配主题品牌色，`assembleHap` 成功。
- 大文件扫描发现的 `SearchPage.ets`（1105 行）与 `DatabaseHelper.ets`（1083 行）均为本轮之前已有的大文件；本轮未继续向其扩展分类管理职责。第三方 `oh_modules` 文件不属于本仓库治理范围。
