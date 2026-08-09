# HarmonyOS 全量分类功能 Module Plan

## 模块拆分

- `category-contract`：KMP 的分类命令、结果 DTO、分类筛选状态与缺失引用规则。
- `category-infra`：KMP C ABI、Harmony NAPI、`KmpPersistenceService` 与 `CategoryRepository` 的读写桥接和最近成功快照。
- `category-editor`：任务/习惯共用的 `CategoryPickerSheet`、快速新建分类与表单接线。
- `category-sidebar`：现有 `SideBarContainer` 的筛选区和管理模式；包含创建、编辑、删除确认。
- `category-projection`：任务、习惯模型和卡片投影；同时为主页任务/习惯列表执行分类筛选。

## 平台映射

- iOS：仅作为已定分类原语和交互语义参考，本轮不修改。
- KMP：`ProjectDeadliner/DeadlinerCore/shared` 的 category domain/repository、habit/task 原子更新和 OHOS C ABI。
- HarmonyOS：`entry/src/main/cpp/napi_init.cpp`、`common/kmp`、`common/repository`、`model`、`pages/components`、`pages/routes/main`。
- Android：本轮不修改。

## 文件拆分策略

- 新的分类筛选状态、选择器和管理内容使用独立文件，避免继续膨胀 `Index.ets`、`MainHomePage.ets` 和现有表单文件。
- 现有大型列表页仅增加状态输入与调用，不承载分类管理 UI。
- 单个核心文件尽量不超过 1000 行有效代码；若必须逃逸，先申请开发者批准。

## 风险点

- ABI 演进若 KMP 库与 NAPI 未同步构建会造成运行时符号缺失，必须以功能版本检查和完整构建验证兜底。
- 习惯和 Deadline 兼容投影共享 UID，分类写入必须在 KMP 事务中保持一致。
- SideBar 手势收起后不得遗留遮罩或命中层；分类 UI 只接入当前已验证的 SideBar 结构。
- 异步读取可能乱序，仓储层仅发布最后成功的分类目录，页面使用请求令牌丢弃过期响应。
