# 浮光语义氛围 Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 对照飞书 revision 8 与现有主页/列表/卡片架构完成自检

## 阶段 2：基础设施

- [x] 建立语义 contract、DeadlineStatusResolver 与 PageToneResolver
- [x] 建立 SemanticPalette，并与主题/分类 palette 分离
- [x] 增加 resolver 单元测试并登记测试套件

## 阶段 3：功能实现

- [x] 任务列表改为统一 resolver 映射状态、进度与快照
- [x] 习惯列表按当前可见结果生成并发布快照
- [x] 接入 SemanticTopAtmosphere
- [x] MainHomePage 保存任务/习惯快照并以滚动进度驱动氛围收缩
- [x] 检查分类/品牌色不污染语义色，完成深浅色 token
- [x] 完成一个实质实现批次后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 执行 resolver 单元测试
- [x] 显式设置 `DEVECO_HOME` 执行 HarmonyOS 构建
- [ ] 记录浅色/深色、6 tone、滚动 0/0.5/1 与状态切换回归结果
- [x] 回写最终实现状态

## 验证记录

- 2026-08-09：功能实现前已创建全工作区保护提交 `42c2738`。
- 2026-08-09：规格前置大文件扫描发现仓库既有 `SearchPage.ets`（1100 有效行）、`DatabaseHelper.ets`（1083 有效行）和 3 个第三方依赖超限；本功能不修改这些文件。
- 2026-08-09：新增语义文件与接线完成，`git diff --check` 通过；最终扫描未增加任何超过 1000 有效行的文件，超限清单与基线一致。
- 2026-08-09：显式设置 `DEVECO_HOME=/Applications/DevEco-Studio.app/Contents` 与 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`，执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（13.394 秒）。
- 2026-08-09：完整测试入口被既有 `DeadlinerToolAdapter.test.ets` 的 40 个 ArkTS 严格类型错误阻断；临时隔离入口后执行 `SemanticResolver.test.ets`，测试构建与执行结果 `BUILD SUCCESSFUL`（19.414 秒），随后已恢复完整测试入口。
- 2026-08-09：尚未连接模拟器或真机，浅色/深色、六 tone、滚动 0/0.5/1 和状态切换的目视回归保留为交付后验证项，不宣称已通过。

## 修订任务：根级统一浮光

- [x] 恢复任务卡 indicator 风格切换
- [x] 删除任务/习惯列表顶部状态卡片
- [x] 删除 `MainHomePage` 内的重复浮光实例
- [x] 在 `Index` 根层接入唯一浮光并扩展到顶部安全区后面
- [x] 清单 Tab 使用语义 tone，其他 Tab 使用各自模块 Tab 颜色
- [x] 执行规格校验、大文件扫描、静态检查与统一构建
- [x] 回写修订实现与验证结果

- 2026-08-09：根级统一浮光修订完成；`assembleHap` 首次验证 `BUILD SUCCESSFUL`（15.593 秒），随后将 Tab 光斑的 `fill` 改为兼容性更好的 `backgroundColor`，增量构建再次 `BUILD SUCCESSFUL`（6 秒）。
- 2026-08-09：规格校验、`git diff --check` 通过；大文件扫描仍为原有 5 个文件，本修订未新增超限文件。
- 2026-08-09：根据交互回归反馈，将浮光从页面上方 overlay 调整为基础背景与导航内容之间的背景层，根级 Stack 固定 Top 对齐，并移除其他 Tab 的 `useWhiteGlow` 可见性过滤。
- 2026-08-09：上述背景层、顶部定位及全 Tab 显示修复执行 `assembleHap`，结果 `BUILD SUCCESSFUL`（13.041 秒）。
- 2026-08-09：纠正清单浮光颜色来源：移除固定深浅色常量，改为随 `currentTheme` 复用 `undergo / completed / near / passed` 的基础 indicator 色；清单与其他 Tab 统一使用 `0.22` 浮光层透明度，`assembleHap` 验证 `BUILD SUCCESSFUL`（15.194 秒）。
- 2026-08-09：非清单 Tab 浮光取色调整为多彩主题使用当前 Tab 模块色，其余主题统一使用 `theme.brand`；`assembleHap` 验证 `BUILD SUCCESSFUL`（12.632 秒）。
- 2026-08-09：新增默认开启且持久化的“顶部浮光”外观开关；根层将 tone/Tab/主题收敛为单一颜色输入，浮光以约 420ms 双层交叉淡化响应颜色变化；添加 Sheet 关闭时显式刷新对应列表与语义快照；`assembleHap` 验证 `BUILD SUCCESSFUL`（13.455 秒）。
- 2026-08-10：修复冷启动与异步刷新时的颜色断链：清单 tone 改由根级可观察字符串状态传递，颜色层以独立 key 强制刷新；主 Tabs 与各页面导航宿主改为透明以透出唯一根级浮光，现有卡片材质保持不变；规格校验通过，大文件清单与基线一致，`assembleHap` 验证 `BUILD SUCCESSFUL`（14.877 秒）。
- 2026-08-10：确认颜色回归由交叉淡化新增的 `Prop → Watch → Timer → State` 颜色缓存链造成；撤除内部 `incoming/outgoing` 颜色副本，恢复目标色直接参与渐变绘制，保留颜色 key 作为绘制节点标识；`assembleHap` 验证 `BUILD SUCCESSFUL`（12.195 秒）。
- 2026-08-10：优化整屏浮光质感：保留从顶部到屏幕底部的完整染色范围，将色层浓度调整为 `0.18` 并使用 `SCREEN` 混合以减少浅色背景灰脏感；多彩主题的清单 Tab 选中色从 `module_list` 修正为 `theme.brand`，其他 Tab 保持模块色；`assembleHap` 验证 `BUILD SUCCESSFUL`（21.239 秒）。
- 2026-08-10：真机对比否决线性底色与径向聚光的复合方案：局部聚光使整体质感不如原有渐变；最终恢复 `0.18` 浓度、在屏幕 `0.6` 位置淡出透明的单层线性渐变，并移除会在当前背景材质上冲淡目标色的 `SCREEN` 混合。
- 2026-08-10：定位渐变中段灰脏来自目标色向透明黑/透明白插值时 RGB 同时漂移；改为解析当前目标色并生成 RGB 相同、alpha 为 0 的终点色，使渐变只衰减透明度。
