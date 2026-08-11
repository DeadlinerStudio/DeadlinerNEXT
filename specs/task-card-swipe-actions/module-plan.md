# Task Card Swipe Actions Module Plan

## 模块拆分

- `card-presentation`：`TaskItemCard.ets` 负责信息布局、圆形动作区呈现、分离/拉伸过渡、短滑停驻、长滑判定与回弹动画。
- `task-action-host`：`TaskListSection.ets` 负责编辑、删除确认及既有状态转换业务回调。

## 平台映射

- iOS 参考：`Deadliner/Features/Home/Components/DDLItemCard.swift`，只作为布局顺序和动作语义基准。
- HarmonyOS 展示：`entry/src/main/ets/pages/components/TaskItemCard.ets`。
- HarmonyOS 页面接线：`entry/src/main/ets/pages/routes/main/TaskListSection.ets`。

## 文件拆分策略

- 交互状态保持在可复用卡片组件内，不下沉到 repository。
- 页面继续复用现有 `handleStateAction`、`handleSecondaryAction`、`handleDelete` 和 `TaskEditSheet`。
- 不向已超过 1000 行的 `SearchPage.ets` 增加新职责；未提供编辑/删除回调的卡片禁用该滑动方向。

## 风险点

- 前景卡片位移后，背景按钮必须保持可点击且不拦截未露出的区域。
- 长滑阈值依赖实测卡片宽度；未达到阈值时只能停驻或回弹，不能误触业务操作。
- 动态间距与胶囊宽度之和必须始终匹配实际揭示宽度，避免出现整片衔接色或透明断层。
- 手势开始时缓存当前停驻偏移，更新阶段使用“缓存偏移 + 本次手势偏移”，保证连续拖动不跳变；当前首次展开触发距离为 `84vp`，吸附停驻宽度为 `112vp`，停驻后的反向关闭距离为 `32vp`。
- 四个动作的颜色沿用现有 `chart_green`、`chart_yellow/chart_red`、`chart_blue` 和 `chart_red` 资源。
- 仅当 `currentIndicatorKey` 为 `ios` 时覆盖动作语义色：完成/撤销完成为 `ios_green`，放弃/恢复为 `ios_orange`，编辑为 `ios_blue`，删除为鸿蒙 `warning`；归档与其他 indicator 保持原路径。
- 卡片通过任务 `dbId` 与共享 `activeTaskCardSwipeId` 协调单开状态；活跃 ID 变化时，非活跃且存在偏移的卡片使用响应式弹簧动画关闭。
