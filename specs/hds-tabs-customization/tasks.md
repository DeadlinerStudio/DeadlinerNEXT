# HdsTabs 底栏自定义 Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成 iOS 交互对照与 ArkTS / ArkUI 约束自检

## 阶段 2：基础设施

- [x] 新增并加载底栏配置 Preferences、默认值与归一化规则

## 阶段 3：功能实现

- [x] 实现底栏自定义二级设置页和路由入口
- [x] 将根 HdsTabs 改为按配置动态渲染
- [x] 大型改动完成后统一编译：`assembleHap` 成功（2026-08-05）
- [x] 按渲染策略切换灵感 SVG，并为未显示于底栏的标签增加“我的”页快捷导航目的地

## 阶段 4：验证与回写

- [x] 执行规格校验：`validate_feature_spec.py` 通过
- [x] 执行大文件扫描：仅报告既有 `SearchPage.ets`、`DatabaseHelper.ets` 与依赖目录超限，本次文件均低于阈值
- [x] 回写最终实现状态
- [x] 追加功能构建验证：`assembleHap` 成功（2026-08-05）
- [x] 沉浸光感开启时将所有 Tab 的有效选中色收口为 scoped `brand`，关闭时保留 `tabIcon/cold` 配置
- [x] 规则调整后执行无 daemon `assembleHap`，结果 `BUILD SUCCESSFUL in 12 s 677 ms`（2026-08-11）
- [x] 沉浸光感关闭时为未选中 Tab 增加浅色/深色专用的干净中性灰
- [x] 中性灰调整后校验两套资源 JSON，并完成无 daemon `assembleHap`：`BUILD SUCCESSFUL in 13 s 107 ms`（2026-08-11）
