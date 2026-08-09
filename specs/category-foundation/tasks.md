# 分类功能 UI 基座 Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 通过现有 KMP C ABI、Category domain、Huawei `SideBarContainer` 官方文档及飞书分类图标原语自检

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构：现有任务 payload 已含 `categoryUid`，但现有 C ABI 缺少分类目录 RPC
- [x] 新增并验证 KMP 分类目录 RPC、NAPI 绑定和 ArkTS DTO adapter（bridge v9；`deadliner_persistence_category_catalog_json`）

## 阶段 3：功能实现

- [x] 实现任务分类展示、根页面 `SideBarContainer { 分类 HdsNavigation, HdsTabs }` 容器、多选筛选、导航栏双入口开关、原生遮罩/显隐动画与 HarmonyOS 图标语义映射
- [x] 完成一批跨仓库改动后构建 KMP library 与 HarmonyOS HAP

## 阶段 4：验证与回写

- [x] 执行规格校验：`validate_feature_spec.py specs/category-foundation` 通过
- [x] 执行大文件扫描：新增文件均未超限；仓库仍有 5 个既存超限文件（含 `SearchPage.ets`、`DatabaseHelper.ets` 和第三方依赖），本批未扩张它们
- [x] 回写最终实现状态、编译结果与未实现边界：KMP `linkReleaseSharedOhosArm64` 产出 v9 library；DevEco `assembleHap` 成功（2026-08-05）；`SideBarContainer` 以分类 `HdsNavigation` 和 `AdaptedHdsTabs` 为直接子节点，任务卡保持 76vp
