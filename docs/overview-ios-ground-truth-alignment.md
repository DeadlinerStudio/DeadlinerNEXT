# Overview 对齐文档（iOS Ground Truth）

本文用于对齐 Deadliner 的 Overview/概览页面在 iOS 与 HarmonyOS 之间的行为差异。

- Ground Truth：iOS 实现
- 目标：HarmonyOS 端最终在业务口径、卡片结构、触发时机、持久化行为上与 iOS 保持一致
- 范围：`总览`、`趋势`、`上月` 三个分段，以及它们背后的统计与月报逻辑

## 1. 参考实现

### iOS 参考文件

- `OverviewView`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/OverviewView.swift`
- `OverviewViewModel`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/OverviewViewModel.swift`
- `Overview 统计卡片`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/Components/OverviewStatsSection.swift`
- `Trend 卡片`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/Components/TrendAnalysisSection.swift`
- `Dashboard`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/Components/DashboardSection.swift`
- `本地配置`：`/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Core/Shared/Settings/LocalValues.swift`

### HarmonyOS 当前实现

- `OverviewPage`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/pages/routes/overview/OverviewPage.ets`
- `OverviewViewModel`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/pages/routes/overview/OverviewViewModel.ets`
- `Overview 统计卡片`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/pages/routes/overview/OverviewStatsSection.ets`
- `Trend 卡片`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/pages/routes/overview/TrendAnalysisSection.ets`
- `Dashboard`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/pages/routes/overview/DashboardSection.ets`
- `统计工具`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/utils/OverviewUtils.ets`
- `本地配置`：`/Users/aritxonly/Codes/HarmonyOS/Deadliner/entry/src/main/ets/common/local/LocalValues.ets`

## 2. iOS Ground Truth

## 2.1 页面结构

iOS Overview 页由一个 `List + Section Header Picker` 组成，顶部三个分段为：

- `总览`
- `趋势`
- `上月`

对应逻辑见 `OverviewView.swift:48-120`。

行为规则：

- `总览`、`趋势` 两个 tab 支持进入编辑态并拖拽排序
- `上月` tab 顶部右侧不是 `EditButton`，而是分享按钮，占位中，尚未真正实现
- 页面滚动会通过 `onScrollProgressChange` 向外同步滚动进度，用于主容器标题栏/顶部渐变联动

## 2.2 ViewModel 生命周期与刷新机制

`OverviewViewModel` 的关键行为见 `OverviewViewModel.swift:107-143`、`165-203`：

- 初始化时先加载卡片顺序，再加载数据
- 监听 `ddlDataChanged`，收到后自动刷新 Overview 数据
- 监听 `ddlRequestMonthlyAnalysis`，收到后触发“上月 AI 分析”

这意味着 iOS 的 Overview 不是纯粹的“进页加载一次”，而是具备数据变更后的自动刷新能力。

## 2.3 卡片定义

### 总览卡片

iOS `OverviewCard` 只有 3 个：

- `ACTIVE_STATS`
- `COMPLETION_TIME`
- `HISTORY_STATS`

见 `OverviewViewModel.swift:12-16`。

### 趋势卡片

iOS `TrendCard` 有 4 个：

- `CONTRIBUTION_HEATMAP`
- `DAILY_TREND`
- `MONTHLY_TREND`
- `WEEKLY_TREND`

默认顺序见 `OverviewViewModel.swift:101-103`。

这里要特别注意：iOS 的趋势页默认第一个卡片是 `活跃热力图`，不是“本周完成情况”。

## 2.4 总览页统计口径

核心统计见 `OverviewViewModel.swift:215-308`。

### 今日概况

iOS 的“今日概况”包含 4 个指标：

- 今日完成：`active && isCompleted && completeTime 在今天`
- 待办任务：`active && 非完成 && 非放弃 && endTime >= now`
- 今日逾期：`active && 非完成 && 非放弃 && endTime 在今天且已过期`
- 已放弃：`active && state.isAbandonedLike`

注意：

- “待办任务”在 iOS 口径里不是“今天要做的任务数”，而是“当前仍未完成且尚未过期的 active 任务数”
- 放弃任务不计入待办，也不计入逾期
- 今日概况有 4 项，不能少

### 历史统计

iOS 历史统计包含 4 类：

- `累计完成`
- `当前待办`
- `累计放弃`
- `累计逾期`

见 `OverviewViewModel.swift:250-264`。

其中：

- `当前待办 = 全量任务里 非完成 且 非放弃`
- `累计逾期 = active 且 非完成 且 非放弃 且 endTime < now`

### 完成时间分布

iOS 固定输出 4 个时间桶，哪怕某个桶是 0 也会保留：

- 深夜
- 上午
- 下午
- 晚上

见 `OverviewViewModel.swift:266-284`。

这意味着图表类别是稳定的，不会因为无数据而缺项。

## 2.5 趋势页统计口径

### 活跃热力图

iOS 计算最近 150 天内，每天完成任务数，作为 contribution heatmap 数据源。

见：

- 数据生产：`OverviewViewModel.swift:289-290`、`524-538`
- 卡片实现：`TrendAnalysisSection.swift` 中 `ContributionHeatmapCard`

### 本周完成情况

iOS 的 `dailyStats` 口径见 `OverviewViewModel.swift:398-430`：

- `completedCount`：按 `completeTime` 落到当天的完成数
- `overdueCount`：按 `endTime` 落到当天的“未完成且已经过期”数量

这不是“逾期完成数”，而是“当天到期但已逾期未完成的任务数”。

### 每月趋势

iOS 的 `monthlyStats` 口径见 `OverviewViewModel.swift:472-510`：

- `totalCount`：按 `endTime` 所在月份统计任务总数
- `completedCount`：同一批任务里，`isCompleted == true` 的数量，归属仍然按 `endTime` 所在月份
- `overdueCompletedCount`：同一批任务里，`completeTime > endTime` 的数量，归属仍然按 `endTime` 所在月份
- 统计窗口是最近 `12` 个月

这里非常关键：iOS 月趋势的三条线全部按任务的 `截止月份(endTime month)` 归属，而不是按完成月份归属。

### 近 4 周完成

iOS 的 `weeklyStats` 口径见 `OverviewViewModel.swift:512-531`：

- 每个桶是相对当前时间往前推的 4 个 7 天窗口
- 标签是：
  - `本周`
  - `1周前`
  - `2周前`
  - `3周前`
- 统计的是该 7 天窗口内按 `completeTime` 落入区间的完成数

它不是 ISO 周号统计，也不是“第 42 周”这种自然周展示。

## 2.6 上月 Dashboard 口径

iOS Dashboard 由 4 个部分组成，见 `OverviewView.swift:86-96` 和 `DashboardSection.swift:23-73`：

- 月份 Header
- AI 月度洞察卡片或分析中的加载卡片
- 指标网格
- 上月每日活动分布图

### Header

Header 展示的是“上个月名称”，例如 `3月`，见：

- `OverviewViewModel.swift:192-198`
- `DashboardSection.swift:240-260`

### 指标口径

iOS Dashboard 指标在 `computeMetrics` 中生成，见 `OverviewViewModel.swift:533-609`。

口径如下：

- 统计范围：`endTime` 落在上个月的任务
- 对比范围：`endTime` 落在上上个月的任务

指标列表：

- `上月任务数`
- `上月完成`
- `上月完成率`
- `上月逾期数`
- `最活跃时段`
- `平均耗时`

细节：

- `上月逾期数` 在 iOS 中等于“上月任务里仍未完成的数量”，不是“逾期完成数”
- `变化量` 显示为相对上上月的百分比变化；当基线 `prev <= 0` 时，不显示变化
- `最活跃时段` 来自“上月已完成任务的完成时间桶”
- `平均耗时` 只统计同时具备 `startTime` 和 `completeTime` 且 `completeTime >= startTime` 的已完成任务

### AI 月度洞察

iOS 具备完整的“上月 AI 分析”能力，见 `OverviewViewModel.swift:311-381`：

- 页面加载时，如果本地缓存里已有本月对应分析，则直接复用
- 否则自动触发一次上月分析
- 也支持通过 `ddlRequestMonthlyAnalysis` 手动触发
- 结果会持久化到本地：
  - `monthlyAnalysis`
  - `lastAnalyzedMonth`

用于生成 AI 分析的输入：

- `monthName`
- `metricsSummary`
- `completedTaskNames`

### 上月活动分布图

iOS 会额外展示一个“上个月每日完成频率”热力格，见 `DashboardSection.swift:176-238`。

数据来自 `lastMonthDailyStats`，见 `OverviewViewModel.swift:432-470`：

- 逐日生成上个月每一天
- `completedCount` 按 `completeTime` 落日
- `overdueCount` 也会计算，但当前 Dashboard UI 只使用 `completedCount`

## 2.7 本地持久化规则

iOS 会持久化：

- Overview 卡片顺序
- Trend 卡片顺序
- 月分析 JSON
- 最近一次已分析月份

见 `LocalValues.swift:249-281`。

并且在卡片顺序读取时会做“缺失卡片补齐”，不是简单信任本地数组，见 `OverviewViewModel.swift:145-163`。

## 3. HarmonyOS 当前实现

## 3.1 已有能力

HarmonyOS 当前已经具备：

- 三个分段：`总览 / 趋势 / 上月`
- Overview / Trend 卡片排序和本地持久化
- 今日概况 / 完成时间分布 / 历史统计
- 本周完成 / 每月趋势 / 近 4 周完成
- Dashboard 指标卡片

对应文件：

- 页面：`OverviewPage.ets`
- VM：`OverviewViewModel.ets`
- 工具：`OverviewUtils.ets`

## 3.2 当前与 iOS 的主要差距

以下差距按优先级排序。

### P0: 趋势页缺少 `活跃热力图`

iOS `TrendCard` 有 4 个卡片，并默认包含 `CONTRIBUTION_HEATMAP`。

Harmony 当前 `TrendCard` 只有 3 个，见 `OverviewViewModel.ets:18-22`，完全缺少：

- 卡片定义
- 数据计算
- UI 呈现
- 排序持久化兼容

这是结构性差距，必须补齐。

### P0: Dashboard 统计口径与 iOS 完全不同

Harmony 当前 Dashboard 逻辑在 `OverviewUtils.ets:265-407`，核心问题有三层：

- 统计范围按 `completeTime` 落在上月筛选，而 iOS 是按 `endTime` 落在上月筛选
- `total` 实际上只统计了“有 completeTime 的项”，并不是“上月任务总数”
- `overdue` 通过 `isOverdue(item)` 计算，它依赖“当前时间是否已经超过 endTime 且任务未完成”，这与 iOS 的“上月仍未完成数量”口径不一致

这会导致 Harmony 的 Dashboard 数字与 iOS 大面积不一致。

### P0: 缺少 AI 月度洞察

Harmony 目前的 `上月` 页只有 Header 和指标卡片，没有：

- AI 分析中状态
- AI 洞察卡片
- 手动触发月分析
- `monthlyAnalysis` / `lastAnalyzedMonth` 持久化
- 生成分析的业务链路

也没有发现与 iOS 对齐的月分析入口。

### P0: 缺少“上月活动分布图”

iOS Dashboard 底部有 `LastMonthActivityMap`。

Harmony 当前 `DashboardSection.ets` 中没有对应模块，仅渲染：

- Header
- Metrics WaterFlow

因此 `上月` 页信息量不足，也与 iOS 主视觉结构不一致。

### P1: 今日概况缺少“已放弃”

iOS 今日概况是 4 项，Harmony 当前只有 3 项：

- 今日完成
- 待办任务
- 今日逾期

缺少：

- 已放弃

见 `OverviewStatsSection.ets` 中 `ActiveStatsCard`。

### P1: 历史统计缺少“累计放弃”

iOS 历史统计为 4 类：

- 累计完成
- 当前待办
- 累计放弃
- 累计逾期

Harmony 当前只写入了 3 类，见 `OverviewViewModel.ets:107-111`，缺少：

- 累计放弃

### P1: Harmony 没有排除 abandoned 任务

iOS 在多个关键统计里显式排除了 `state.isAbandonedLike`：

- 今日待办
- 今日逾期
- 历史待办
- 历史逾期

Harmony 当前 Overview 统计大量依赖 `isCompleted` / `isArchived` / `isOverdue`，但没有统一排除 abandoned 状态，见 `OverviewViewModel.ets:92-129`。

这会导致放弃任务被错误纳入：

- 待办
- 历史待办
- 逾期

与 iOS 口径不一致。

### P1: 本周完成情况的“逾期”口径不一致

iOS：

- `overdueCount` = 当天 `endTime` 落日且任务仍未完成且已过期

Harmony：

- `overdue` = 当天完成的任务里，`completeTime > endTime` 的数量

见 `OverviewUtils.ets:127-136`。

也就是说：

- iOS 展示“当天到期后仍未完成的积压”
- Harmony 展示“当天完成但属于逾期完成的数量”

这两个指标不是一回事。

以 iOS 为准时，Harmony 需要改成 iOS 口径。

### P1: 每月趋势口径不一致

iOS 月趋势：

- 三个值都按 `endTime` 所在月份归属
- 窗口长度 = 12 个月
- 第三条线是 `逾期完成数`

Harmony 月趋势：

- `total` 按 `endTime` 月份
- `completed` 按 `completeTime` 月份
- `overdue` 按 `completeTime` 月份且 `completeTime > endTime`
- 窗口长度 = 6 个月

见 `OverviewUtils.ets:148-193`。

因此 Harmony 与 iOS 的折线图既不是同一批数据，也不是同一展示周期。

### P1: 近 4 周标签与聚合方式不一致

iOS：

- 标签：`本周 / 1周前 / 2周前 / 3周前`
- 聚合：连续 7 天窗口

Harmony：

- 标签：`第X周`
- 聚合：按 ISO 周号聚合

见 `OverviewUtils.ets:195-229`。

这会影响跨年周、部分周统计，以及 UI 文案本身。

### P1: 完成时间分布类别不稳定

iOS 固定输出 4 个桶，即使值为 0 也会保留。

Harmony 当前是从 `bucketMap.entries()` 动态生成，仅保留出现过的桶，见 `OverviewViewModel.ets:113-123`。

这会导致：

- 某些时间桶消失
- 图表类别不稳定
- 跨端截图不一致

### P1: Dashboard 指标列表不一致

iOS Dashboard 指标：

- 上月任务数
- 上月完成
- 上月完成率
- 上月逾期数
- 最活跃时段
- 平均耗时

Harmony 当前 Dashboard 指标：

- 统计月份
- 总任务数
- 完成数
- 逾期数
- 完成率
- 逾期率
- 平均耗时

见 `OverviewUtils.ets:381-405`。

差异包括：

- 多出 `统计月份`
- 多出 `逾期率`
- 缺少 `最活跃时段`
- 标签命名不一致
- 变化量算法不一致，Harmony 目前是绝对值/整数差，iOS 目前是相对百分比

### P2: 卡片顺序读取的容错性不足

iOS 读取排序配置时会：

- 先解析本地值
- 再把缺失的卡片补回去

Harmony 当前直接把 `string[]` 强转成 enum 数组，见 `OverviewViewModel.ets:65-79`，没有：

- 非法值过滤
- 新增卡片自动补齐

这在后续补入 `CONTRIBUTION_HEATMAP` 后会直接暴露问题。

### P2: 自动刷新机制不一致

iOS 会监听 `ddlDataChanged` 自动刷新。

Harmony 当前主要依赖：

- `aboutToAppear`
- tab 切换到概览页时重新 `loadData`

未看到与 iOS 等价的全局数据变更监听。

这会导致跨页面编辑任务后，Overview 数据新鲜度不稳定。

### P2: 顶部交互与容器联动未对齐

iOS 还有一些 Harmony 尚未对齐的页面级行为：

- `总览/趋势` 显示编辑按钮；`上月` 显示分享按钮占位
- 页面滚动进度回传给外部，用于标题栏/overlay 联动
- RichMainView 中还带有 AI 月分析入口状态

这些目前不属于统计口径问题，但属于最终交互对齐项。

## 4. 建议的收敛顺序

建议按下面顺序补齐，避免边做边返工。

### 第一阶段：先修统计口径

1. 统一 `OverviewViewModel.ets` 的 snapshot 统计，补齐 abandoned 逻辑。
2. 重写 `OverviewUtils.ets` 的日/周/月/Dashboard 统计口径，完全对齐 iOS。
3. 趋势页补上 `CONTRIBUTION_HEATMAP` 的数据模型与默认排序。

### 第二阶段：补齐 Dashboard 结构

1. `DashboardSection.ets` 改成与 iOS 同结构：
   - Header
   - AI 洞察/分析中
   - 指标网格
   - 上月活动分布图
2. 指标标签与变化量算法全部以 iOS 为准。

### 第三阶段：补齐月分析能力

1. 增加 `monthlyAnalysis`
2. 增加 `lastAnalyzedMonth`
3. 增加本地缓存读取
4. 增加手动触发入口
5. 增加分析中的 UI 态

### 第四阶段：收尾交互与容错

1. 排序配置读取补齐“过滤非法值 + 缺失值回填”
2. 补全顶部 toolbar 行为
3. 补齐数据变更后的自动刷新机制

## 5. 实施约束

后续所有 HarmonyOS Overview 相关改动，应遵守以下原则：

- iOS 代码是 Ground Truth，若两端行为冲突，以 iOS 为准
- 不沿用 Harmony 当前 `OverviewUtils.ets` 中与 iOS 不一致的旧口径
- 先对齐业务口径，再做视觉优化
- 新增字符串、颜色、图标资源时遵守项目的鸿蒙开发规范

## 6. 当前结论

当前 HarmonyOS Overview 并不是“样式接近但细节不同”，而是：

- 趋势页少一个核心卡片
- 总览页少放弃维度
- Dashboard 基本统计口径与 iOS 不同
- AI 月分析整条链路缺失

因此后续工作建议按“功能对齐”处理，而不是按“UI 微调”处理。
