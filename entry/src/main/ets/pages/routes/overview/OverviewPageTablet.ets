import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationAttribute,
  HdsNavigationMenuItemOptions } from "@kit.UIDesignKit";
import { DashboardSection } from "./DashboardSection";
import { OverviewStatsSection } from "./OverviewStatsSection";
import { TrendAnalysisSection } from "./TrendAnalysisSection";
import { getImmersiveTitleBarStyle } from "../../../common/style/NavStyles";
import { OverviewViewModel } from "./OverviewViewModel";
import { SortSheet } from "./SortSheet";
import { SortSheetTablet } from "./SortSheetTablet";
import { SettingsConstants as C } from "../../../common/local/SettingsConstants";
import { promptAction } from "@kit.ArkUI";
import { common } from "@kit.AbilityKit";
import { PaperTalkUtils } from "../../../utils/PaperTalkUtils";

@Component
export struct OverviewPageTablet {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(C.KEY_SHOW_PAPERTALK_SHARE) showPaperTalkShare: boolean = true;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  private context = getContext(this) as common.UIAbilityContext;

  // --- 状态控制 ---
  @State isLoading: boolean = true;

  // 独立的弹窗状态控制
  @State isOverviewHelpShow: boolean = false;
  @State isTrendHelpShow: boolean = false;
  @State isDashboardHelpShow: boolean = false;

  @State viewModel: OverviewViewModel = new OverviewViewModel();

  aboutToAppear(): void {
    this.viewModel.loadData().then(() => {
      this.isLoading = false;
    });
  }

  @State isSortSheetShow: boolean = false;

  @Builder SortSheetBuilder() {
    SortSheetTablet({
      viewModel: $viewModel,
      onClose: () => { this.isSortSheetShow = false }
    })
  }

  // --- 独立的 Popup Builders ---

  @Builder OverviewHelpBuilder() {
    Column({ space: 8 }) {
      Text("概览说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 完成分布：").fontWeight(FontWeight.Medium)
        Span("统计任务完成的时间段，柱状图越长代表该时段完成任务越多。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 历史统计：").fontWeight(FontWeight.Medium)
        Span("点击环形图扇区，中间圆环内将显示该状态的具体数值。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder TrendHelpBuilder() {
    Column({ space: 8 }) {
      Text("趋势说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 本周情况：").fontWeight(FontWeight.Medium)
        Span("展示每日完成任务数。点击右上角").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("「显示逾期」").fontColor($r('app.color.chart_red'))
        Span("开关，可对比每日逾期数量。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 每月趋势：").fontWeight(FontWeight.Medium)
        Span("展示近12个月的任务总量、完成量及逾期量走势。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 活跃热力图：").fontWeight(FontWeight.Medium)
        Span("按天展示最近一段时间的任务活跃度，颜色越深表示当天完成任务越多。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder DashboardHelpBuilder() {
    Column({ space: 8 }) {
      Text("看板说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 数据汇总：").fontWeight(FontWeight.Medium)
        Span("基于您的所有任务数据计算出的关键指标。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 变化指标：").fontWeight(FontWeight.Medium)
        Span("箭头（").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("↑").fontColor($r('app.color.chart_green'))
        Span("/").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("↓").fontColor($r('app.color.chart_red'))
        Span("）代表与上周期相比的变化幅度。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  private shareMonthlySummary(): void {
    const payload = PaperTalkUtils.buildOverviewPayload(
      this.viewModel.lastMonthName,
      this.viewModel.monthlyAnalysis,
      this.viewModel.isAnalyzing,
      this.viewModel.metrics
    );
    PaperTalkUtils.openPrintOrStore(this.context, payload).catch((error: Error) => {
      console.error(`[OverviewPageTablet] Share monthly summary failed: ${error}`);
      promptAction.showToast({ message: '暂时无法打开纸语或应用商店' });
    });
  }

  private buildTitleMenus(): HdsNavigationMenuItemOptions[] {
    const menuItems: HdsNavigationMenuItemOptions[] = [
      {
        content: {
          icon: $r('sys.symbol.text_and_arrow_down'),
          action: () => {
            this.isSortSheetShow = true;
          }
        }
      }
    ];

    if (this.showPaperTalkShare) {
      menuItems.push({
        content: {
          icon: $r('sys.symbol.share'),
          action: () => {
            this.shareMonthlySummary();
          }
        }
      });
    }

    return menuItems;
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (!this.isLoading) {
          Row() {
            // === 第一栏：概览统计 ===
            Column() {
              Row() {
                Text('概览统计')
                  .fontSize(14) // [修复] 字体调小
                  .fontWeight(FontWeight.Medium) // [修复] 字重调轻
                  .fontColor($r('app.color.font_secondary')) // [修复] 颜色调淡

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18) // 图标也稍微调小适配标题
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isOverviewHelpShow = !this.isOverviewHelpShow
                })
                .bindPopup(this.isOverviewHelpShow, {
                  builder: this.OverviewHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isOverviewHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              // 内容区
              Scroll() {
                Column() {
                  OverviewStatsSection({
                    todayCompleted: this.viewModel.todayCompleted,
                    todayTodo: this.viewModel.todayTodo,
                    todayOverdue: this.viewModel.todayOverdue,
                    activeAbandoned: this.viewModel.activeAbandoned,
                    historyStats: this.viewModel.historyStats,
                    completionTimeStats: this.viewModel.completionTimeStats,
                    overdueItems: this.viewModel.overdueItems,
                    cardOrder: this.viewModel.overviewCardOrder,
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')

            // --- 分割线 ---
            Divider()
              .vertical(true)
              .height('100%')
              .strokeWidth(1)
              .color($r('sys.color.ohos_id_color_list_separator'))
              .opacity(0.5)

            // === 第二栏：趋势分析 ===
            Column() {
              Row() {
                Text('趋势分析')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.font_secondary'))

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isTrendHelpShow = !this.isTrendHelpShow
                })
                .bindPopup(this.isTrendHelpShow, {
                  builder: this.TrendHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isTrendHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              Scroll() {
                Column() {
                  TrendAnalysisSection({
                    dailyStats: this.viewModel.dailyStats,
                    monthlyStats: this.viewModel.monthlyStats,
                    weeklyStats: this.viewModel.weeklyStats,
                    contributionStats: this.viewModel.contributionStats,
                    cardOrder: this.viewModel.trendCardOrder
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')

            // --- 分割线 ---
            Divider()
              .vertical(true)
              .height('100%')
              .strokeWidth(1)
              .color($r('sys.color.ohos_id_color_list_separator'))
              .opacity(0.5)

            // === 第三栏：月度总结（看板） ===
            Column() {
              Row() {
                Text('月度总结')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.font_secondary'))

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isDashboardHelpShow = !this.isDashboardHelpShow
                })
                .bindPopup(this.isDashboardHelpShow, {
                  builder: this.DashboardHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isDashboardHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              Scroll() {
                Column() {
                  DashboardSection({
                    metrics: this.viewModel.metrics,
                    dailyStats: this.viewModel.lastMonthDailyStats,
                    lastMonthName: this.viewModel.lastMonthName,
                    analysis: this.viewModel.monthlyAnalysis,
                    isAnalyzing: this.viewModel.isAnalyzing
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.statusBarHeight + 16 })
        } else {
          Column() {
            LoadingProgress()
              .width(64)
              .height(64)
              .color($r('sys.color.ohos_id_color_text_primary'))
            Text("正在加载数据...")
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
        }
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(true),
      content: {
        title: { mainTitle: '概览' },
        menu: {
          value: this.buildTitleMenus()
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .navBarWidth('100%')
    .padding({ top: this.statusBarHeight })
    .bindSheet($$this.isSortSheetShow, this.SortSheetBuilder(), {
      detents: [
        SheetSize.FIT_CONTENT,
        SheetSize.MEDIUM,
        SheetSize.LARGE
      ],
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.Regular,
      onDisappear: () => { this.isSortSheetShow = false },
      title: {
        title: '调整卡片顺序',
        subtitle: '长按以拖动卡片标题'
      }
    })
  }
}
