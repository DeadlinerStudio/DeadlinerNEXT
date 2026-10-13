# Overview Dashboard Module Plan

## 模块拆分
- Core 月投影及专注全量查询：独立 OhosOverviewCApi / overview_bridge，沿用共享领域聚合。
- 月选择与加载：OverviewDashboardModel，与旧 OverviewViewModel 全局统计分离。
- 月 AI 缓存：MonthlyInsightRepository，按月持久化、失败显式重试、请求合并。
- 展示：OverviewPage 根导航、OverviewDashboardContent 卡片、OverviewCalendarCard 月历、OverviewPreviewChart 图表、OverviewDetailPage 独立目的地、OverviewFocusManagement 专注管理、OverviewReviewExport 本机分享。趋势热力图直接消费与 Android 相同的共享 contribution 投影。

## 平台映射
Android ui/overview 为产品及交互参考；HarmonyOS entry/src/main/ets/pages/routes/overview 使用 HDS。共享统计来自 DeadlinerCore，不修改其他平台 UI。

## 文件拆分策略
新模块小于 1000 行；趋势图拆为序列映射、通用图表、精确明细与热力图组件；保留其他既有统计及分享组件，不扩大既有大文件。

## 风险点
当前工作区包含用户未提交修改，保留已有改动。原型浏览器预览受本地协议安全策略限制，源代码可读。沉浸、字号、安全区需设备验收。

## 趋势统一模块
- TrendAnalysisSection：四卡编排、每周期任务 / 专注摘要、独立错误与重试。
- OverviewTrendPresentation：任务 / 专注图序列及标签、明细文案；仅映射共享投影。
- OverviewTrendChart / OverviewTrendMarker：统一 MPChart 柱 / 折线配置与精确点选明细。
- OverviewContributionCard：自适应贡献热力图。
- OverviewTrendSettings：原生 Sheet 中的逾期开关与已有排序入口；LocalValues 持久化。
