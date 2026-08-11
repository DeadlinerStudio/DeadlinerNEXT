# Task Card Swipe Actions Tasks

## 阶段 1：规格冻结

- [x] 对照 iOS 卡片确认信息顺序和双侧动作语义。
- [x] 明确短滑、长滑、多选模式和颜色约束。
- [x] 创建改造前 Git 检查点。

## 阶段 2：基础设施

- [x] 为卡片增加左右动作回调、图标和动作宽度常量。
- [x] 建立短滑停驻、长滑触发和点击关闭规则。

## 阶段 3：功能实现

- [x] 调整星标、分类位置并将卡片高度改为 72vp。
- [x] 实现左、右两组动作按钮和状态文案。
- [x] 在主任务列表接入编辑与删除，复用现有状态动作。
- [x] 对未提供编辑/删除回调的宿主禁用对应滑动方向。

## 阶段 4：验证与回写

- [x] 运行 ArkTS/HarmonyOS 编译并修复错误。
- [x] 执行规格校验和大文件检查。
- [x] 检查最终差异，确认不混入并发的语义浮光改动。

## 实现记录

- 2026-08-10：改造前提交 `f4cfbda` 已创建；主任务卡完成 72vp 布局、双侧双动作、短滑停驻与长滑主动作，并接入编辑 Sheet 和删除确认。
- 2026-08-10：规格校验通过；大文件扫描未新增超限文件；显式设置 `DEVECO_HOME=/Applications/DevEco-Studio.app/Contents` 和 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` 两次执行 `assembleHap`，最终 `BUILD SUCCESSFUL`（19.634 秒）。

## 过渡形态修订

- [x] 冻结“圆形停驻 → 间距增大 → 主按钮拉长”的分段规则。
- [x] 移除整片主动作衔接色，改为独立圆形/胶囊按钮。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：停驻动作改为两个 48vp 圆形按钮；超过 128vp 后先将间距从 8vp 增至 24vp，再持续拉伸完成/恢复或删除按钮；动作区底层恢复为卡片表面色。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（22.391 秒）。

## 连续手势修订

- [x] 冻结透明底层与“当前偏移 + 新手势偏移”的累加规则。
- [x] 将动作区底层改为完全透明。
- [x] 缓存每次手势开始时的卡片偏移，并在更新阶段累加。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：动作区底层改为 `Color.Transparent`；新增 `panStartOffset`，每次拖动用停驻偏移叠加当前 `PanGesture.offsetX`，支持连续关闭、换侧和同向长滑。显式设置 DevEco 环境执行增量 `assembleHap`，结果 `BUILD SUCCESSFUL`（2.145 秒）。

## 连续手势阈值修正

- [x] 确认上一版仍按最终 `±32vp` 判定关闭，未满足完整反向距离。
- [x] 反向关闭改为必须覆盖当前停驻距离，`-128vp + 128vp = 0vp`。
- [x] 移除动作层整宽背景绘制节点的背景、圆角与裁剪效果。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：`finishSwipe` 对已停驻手势单独判定，反向净位移必须覆盖 `panStartOffset` 才关闭；整宽动作层不再设置任何背景、圆角或裁剪 modifier，仅按钮自身绘制。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（14.678 秒）。

## 关闭距离调优

- [x] 将停驻后的反向关闭距离从 128vp 调整为 64vp。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：停驻后的反向关闭阈值统一调整为 64vp；未达到阈值时回到原停驻位置，达到阈值时关闭，继续拖过另一侧阈值则切换动作侧。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（23.343 秒）。

## 展开与关闭阈值拆分

- [x] 跟随停驻宽度调优，将首次展开阈值设为 112vp。
- [x] 将停驻后的反向关闭阈值设为 56vp。
- [x] 保持动作层透明，并将右侧动作组的剩余 8vp 空间放在卡片邻接侧。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：首次展开不再复用旧的 32vp 判定，必须从关闭状态拖到 `±112vp`；停驻后反向拖动 `56vp` 关闭，跨侧则要求最终偏移达到另一侧 `±112vp`。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（14.519 秒）。

## 展开触发距离调优

- [x] 将首次展开和跨侧切换的触发距离从 112vp 调整为 96vp。
- [x] 保持动作停驻宽度为 112vp，反向关闭距离为 56vp。
- [x] 运行统一构建并回写验证结果。

- 2026-08-10：新增独立的 `96vp` 展开触发距离；达到阈值后吸附至 `112vp`，反向关闭仍为 `56vp`。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（15.864 秒）。

## iOS Indicator 动作色

- [x] 监听当前 indicator key，仅在 iOS indicator 下覆盖动作按钮颜色。
- [x] 完成/撤销完成映射 iOS green，放弃/恢复映射 iOS orange，编辑映射 iOS blue，删除映射鸿蒙 warning。
- [x] 归档与其他 indicator 主题保持现有颜色路径。
- [x] 运行统一构建并回写验证结果。

- 2026-08-11：滑动卡片监听 `currentIndicatorKey`；仅 iOS indicator 使用 `ios_green`、`ios_orange`、`ios_blue` 与鸿蒙 `warning` 动作色，其他 indicator 和归档颜色保持原逻辑。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（13.914 秒）。

## 卡片单开与弹簧回弹

- [x] 为滑动卡片传入稳定任务 ID，并共享当前活跃滑动 ID。
- [x] 新卡片开始滑动时自动关闭其他存在偏移的卡片。
- [x] 展开吸附与关闭回弹改用响应式弹簧曲线。
- [x] 运行统一构建并回写验证结果。

- 2026-08-11：主列表与搜索结果将任务 `dbId` 传入滑动卡片；卡片通过 `activeTaskCardSwipeId` 保持单开，新卡片开始拖动时其余卡片弹簧回零。展开与关闭改用 `responsiveSpringMotion`，并迁移到 `UIContext.animateTo`。显式设置 DevEco 环境执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（16.936 秒）。
