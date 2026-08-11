# 浮光语义氛围 Module Plan

## 模块拆分

- `semantic-contract`：定义 `DeadlineSemanticStatus`、`SemanticTone`、`SemanticSnapshot`、习惯可见状态输入和快照空值；不包含 ArkUI 资源。
- `semantic-domain`：`DeadlineStatusResolver` 负责单条任务优先级、时间边界与进度；`PageToneResolver` 负责从当前可见任务/习惯生成页面快照。
- `semantic-palette`：`SemanticPalette` 只把 tone/status 映射到当前 `IndicatorSet` 的基础状态色；浮光透明度由 presentation 层统一控制，并与品牌强调色及 `CategoryColorPalette` 保持隔离。
- `semantic-presentation`：`SemanticTopAtmosphere` 使用语义或 Tab 色绘制单层整屏线性渐变；列表不再增加状态摘要卡。
- `semantic-bridge`：任务/习惯列表在完成现有筛选后生成快照，通过回调同步到 `MainHomePage`；主页根据当前分段选择快照，并只把 tone 与滚动进度传给氛围组件。
- `deadline-card-adapter`：`TaskListSection` 使用 `DeadlineStatusResolver` 生成 `TaskUIModel`；现有 `TaskItemCard` 继续消费兼容 `DDLStatus`，但映射来源收口到 resolver，分类徽标不参与状态 palette。
- `semantic-tests`：纯 ArkTS 单元测试覆盖状态优先级、精确 24 小时边界、无效日期、任务 tone 和习惯完成率。

## 平台映射

- iOS：本轮不修改；以现有固定 `semanticAccent` 和 Features 层氛围表达作为产品对齐基准。
- HarmonyOS contract/domain：`entry/src/main/ets/common/semantic/`。
- HarmonyOS presentation：`entry/src/main/ets/pages/components/semantic/`。
- HarmonyOS 页面接线：`entry/src/main/ets/pages/routes/main/{TaskListSection,HabitListSection,MainHomePage}.ets`，任务卡仅在 `pages/components/TaskItemCard.ets` 做必要 palette/语义适配。
- HarmonyOS tests：`entry/src/test/SemanticResolver.test.ets` 并登记到 `entry/src/test/List.test.ets`。
- Android：本轮不修改；未来对应 `model/domain/semantic`、`ui/main` 和 `ui/components`，沿用相同 enum 与聚合优先级。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 领域契约、单条任务解析、页面聚合、palette、顶部背景分别独立文件，避免形成新的“万能语义文件”。
- `MainHomePage.ets` 只新增快照状态、回调接线和一个背景层，不新增仓储读取或 resolver 逻辑。
- `TaskListSection.ets` 与 `HabitListSection.ets` 只在现有筛选完成点生成/发布快照，不复制颜色或渐变规则。
- 不向 `HomeFocusPanel.ets` 增加代码；可复用的语义计算迁入 domain 层，后续独立重构该未接入组件。

## 风险点

- ArkUI 对接口对象的深层变更追踪不稳定，快照采用每次完整替换，并在渲染 key/枚举 prop 中体现 tone 变化。
- 任务页和习惯页由不同异步链路刷新，主页必须保留两份快照，切换分段时选择对应结果，不能让慢请求覆盖当前分段。
- `radialGradient`、安全区扩展和 HDS 导航背景可能在不同设备形态表现不同；组件必须 `hitTestBehavior(None)` 并通过 phone/medium/wide 构建与视觉检查。
- 顶部氛围不能复用 `theme.brand`，而应和任务卡共同消费当前 `IndicatorSet`；状态资源只随 indicator 风格变化，不被分类或品牌色污染。
- 当前仓库已有大文件基线告警，本功能不得增加告警文件或让接线文件跨过 1000 有效行阈值。

## 实际落地

- `common/semantic` 已按 contract、单任务 resolver、页面 resolver、palette 四个文件拆分；`pages/components/semantic` 只保留根级 Atmosphere 组件。
- `TaskListSection`、`HabitListSection` 与 `MainHomePage` 仅承担快照生成点、发布回调和展示接线；滚动路径未引入仓储读取或截止时间解析。
- `TaskItemCard` 继续消费当前主题的 indicator token，分类 badge 的颜色通路保持独立；`EntryAbility` 只补充当前系统深浅色模式存储。
- 最终大文件扫描未产生新的超限文件，无需规模逃逸批准。

## 根级统一浮光修订

- `Index.ets` 成为唯一浮光宿主，负责依据当前顶级 Tab 选择清单语义 tone，或按主题选择模块 Tab 色/品牌色，并在根级 `Stack` 中把浮光固定于顶部背景层。
- `MainHomePage.ets` 降级为语义状态发布者：保留任务/习惯快照与滚动计算，通过显式回调传给根层，删除本地浮光组件实例。
- `SemanticTopAtmosphere.ets` 同时支持语义 palette 和直接 Tab 色，但每次只渲染一个组件实例。
- `MainHomePage` 将当前清单 tone 写入根级可观察状态，`Index` 直接订阅该原始字符串；页面导航宿主仅负责透出最外层浮光，不自行绘制第二份浮光。
- `TaskItemCard.ets` 恢复既有 `currentTheme` indicator 映射；`DeadlineStatusResolver` 仍作为唯一状态来源，二者职责保持分离。
- `TaskListSection.ets`、`HabitListSection.ets` 删除 Hero 展示及其 import，不删除快照生成逻辑。
- 根级 `HdsNavigation` 使用透明背景并位于浮光之上；浮光不再以 overlay 的 zIndex 覆盖页面内容，也不依赖子页面安全区布局定位。
