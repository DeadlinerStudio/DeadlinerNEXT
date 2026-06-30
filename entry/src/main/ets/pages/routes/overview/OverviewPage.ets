import { BottomBuilderShowType, HdsNavigation, HdsNavigationTitleMode } from "@kit.UIDesignKit";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { ItemRestriction, LengthMetrics, SegmentButtonTextItem, promptAction } from "@kit.ArkUI";
import { DashboardSection } from "./DashboardSection";
import { OverviewStatsSection } from "./OverviewStatsSection";
import { TrendAnalysisSection } from "./TrendAnalysisSection";
import { OverviewViewModel } from "./OverviewViewModel";
import { SortSheet } from "./SortSheet";
import { getImmersiveTitleBarStyle } from "../../../common/style/NavStyles";
import { HdsTitleBarMenuButton } from "../../components/HdsTitleBarMenuButton";
import { HdsTitleBarSegment } from "../../components/HdsTitleBarSegment";
import { SettingsConstants as C } from "../../../common/local/SettingsConstants";
import { common } from "@kit.AbilityKit";
import { PaperTalkUtils } from "../../../utils/PaperTalkUtils";
import {
  AppBreakpoint,
  APP_BREAKPOINT_DEFAULT,
  APP_BREAKPOINT_STORAGE_KEY
} from "../../../common/layout/AppBreakpoints";

@Component
export struct OverviewPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('currentThemeKey') currentThemeKey: string = 'vibrant';
  @StorageLink(C.KEY_SHOW_PAPERTALK_SHARE) showPaperTalkShare: boolean = true;

  readonly SEGMENT_HEIGHT: number = 48;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink(APP_BREAKPOINT_STORAGE_KEY) currentBreakpoint: string = APP_BREAKPOINT_DEFAULT;
  private context = getContext(this) as common.UIAbilityContext;

  @State viewModel: OverviewViewModel = new OverviewViewModel();

  // --- 状态控制 ---
  @State selectedIndexes: number[] = [0];
  @State isLoading: boolean = true;

  @State isSortSheetShow: boolean = false;
  readonly tabButtons: ItemRestriction<SegmentButtonTextItem> = [
    { text: '总览' },
    { text: '趋势' },
    { text: '上月' }
  ] as ItemRestriction<SegmentButtonTextItem>;

  aboutToAppear(): void {
    this.viewModel.loadData().then(() => {
      this.isLoading = false;
    });
  }

  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;

  readonly TARGET_INDEX: number = 1;

  onTabSwitch() {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      console.debug('[OverviewPage] Tab switched to Overview. Reloading data...');
      this.isLoading = true;
      this.viewModel.loadData().then(() => {
        this.isLoading = false;
      });
      this.selectedIndexes[0] = 0;
    } else {
    }
  }

  private usesMediumLayout(): boolean {
    return this.currentBreakpoint === AppBreakpoint.MD;
  }

  @Builder tabSegment() {
    Column() {
      HdsTitleBarSegment({
        buttons: this.tabButtons,
        selectedIndexes: $selectedIndexes,
        maxFontScale: 2,
        segmentHeight: this.SEGMENT_HEIGHT,
        normalWidth: '100%',
        experimentalWidth: '100%',
        experimentalHeight: 52
      })
        .align(Alignment.Center)
    }
    .id(`overview_tabsegment_${this.currentThemeKey}`)
    .width('100%')
    .height('100%')
    .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16) })
    .justifyContent(FlexAlign.Center)
    .constraintSize({ maxWidth: 500 })
  }

  @State isHelpPopupShow: boolean = false

  @Builder helpPopupBuilder() {
    Column({ space: 8 }) {
      if (this.selectedIndexes[0] === 0) {
        // === 0: OverviewStatsSection (概览) ===
        Text("概览说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        // 1. 完成分布 (CompletionTimeCard)
        Text() {
          Span("• 完成分布：").fontWeight(FontWeight.Medium)
          Span("统计任务完成的时间段（如深夜、上午等），柱状图越长代表该时段完成任务越多。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 2. 历史统计 (HistoryStatsCard)
        Text() {
          Span("• 历史统计：").fontWeight(FontWeight.Medium)
          Span("点击环形图扇区").fontColor($r('sys.color.ohos_id_color_text_primary')) // Highlight interaction
          Span("，中间圆环内将显示该状态（完成/待办/逾期）的具体数值。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

      } else if (this.selectedIndexes[0] === 1) {
        // === 1: TrendAnalysisSection (趋势) ===
        Text("趋势说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        // 1. 本周情况 (DailyCompletedCard)
        Text() {
          Span("• 本周情况：").fontWeight(FontWeight.Medium)
          Span("展示每日完成任务数。点击右上角").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("「显示逾期」").fontColor($r('app.color.chart_red')) // Highlight specific UI element
          Span("开关，可对比每日逾期数量。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 2. 每月趋势 (MonthlyTrendCard)
        Text() {
          Span("• 每月趋势：").fontWeight(FontWeight.Medium)
          Span("展示近12个月的任务总量、完成量及逾期量走势，帮助您分析长期效率变化。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 3. 近4周完成 (PrevWeeksCard)
        Text() {
          Span("• 近4周完成：").fontWeight(FontWeight.Medium)
          Span("对比最近4周的周完成量，直观查看短期内的效率波动。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        Text() {
          Span("• 活跃热力图：").fontWeight(FontWeight.Medium)
          Span("按天展示最近一段时间的活跃程度，颜色越深表示当天完成任务越多，可快速识别持续投入和断档区间。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

      } else if (this.selectedIndexes[0] === 2) {
        // === 2: DashboardSection (看板) ===
        Text("看板说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        Text() {
          Span("• 数据汇总：").fontWeight(FontWeight.Medium)
          Span("基于您的所有任务数据计算出的关键指标（如总任务数、平均耗时等）。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        Text() {
          Span("• 变化指标：").fontWeight(FontWeight.Medium)
          Span("部分指标显示的箭头（").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("↑").fontColor($r('app.color.chart_green'))
          Span("/").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("↓").fontColor($r('app.color.chart_red'))
          Span("）代表与上周期相比的变化幅度。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder SortSheetBuilder() {
    SortSheet({
      viewModel: $viewModel, // 传递引用
      selectedTabIndex: this.selectedIndexes[0],
      onClose: () => { this.isSortSheetShow = false }
    })
  }

  @Builder titleMenuBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Row({ space: 10 }) {
        if (this.selectedIndexes.length > 0 && this.selectedIndexes[0] !== 2) {
          HdsTitleBarMenuButton({
            icon: $r('sys.symbol.text_and_arrow_down'),
            onButtonClick: () => {
              if (this.selectedIndexes[0] <= 1) {
                this.isSortSheetShow = true;
              } else {
                promptAction.showToast({ message: '当前页面暂不支持排序' });
              }
            }
          })
        }

        if (this.selectedIndexes.length > 0 && this.selectedIndexes[0] === 2 && this.showPaperTalkShare) {
          HdsTitleBarMenuButton({
            icon: $r('sys.symbol.share'),
            onButtonClick: () => {
              this.shareMonthlySummary();
            }
          })
        }

        HdsTitleBarMenuButton({
          icon: $r('sys.symbol.questionmark_circle'),
          onButtonClick: () => {
            this.isHelpPopupShow = true;
          }
        })
        .bindPopup(this.isHelpPopupShow, {
          builder: this.helpPopupBuilder,
          placement: Placement.Bottom,    // 气泡位置
          mask: false,
          backgroundBlurStyle: BlurStyle.Regular,
          enableArrow: true,
          onStateChange: (e) => {
            if (!e.isVisible) {
              this.isHelpPopupShow = false
            }
          }
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 16 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .id(`overview_titlemenu_${this.currentThemeKey}`)
    .height('100%')
    .width('100%')
  }

  private shareMonthlySummary(): void {
    const payload = PaperTalkUtils.buildOverviewPayload(
      this.viewModel.lastMonthName,
      this.viewModel.monthlyAnalysis,
      this.viewModel.isAnalyzing,
      this.viewModel.metrics
    );
    PaperTalkUtils.openPrintOrStore(this.context, payload).catch((error: Error) => {
      console.error(`[OverviewPage] Share monthly summary failed: ${error}`);
      promptAction.showToast({ message: '暂时无法打开纸语或应用商店' });
    });
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (!this.isLoading) {
          TopSafeContainer({
            topAvoidHeight: this.statusBarHeight + this.SEGMENT_HEIGHT,
            needBgTransparent: true
          }) {
            if (this.selectedIndexes[0] === 0) {
              OverviewStatsSection({
                todayCompleted: this.viewModel.todayCompleted,
                todayTodo: this.viewModel.todayTodo,
                todayOverdue: this.viewModel.todayOverdue,
                activeAbandoned: this.viewModel.activeAbandoned,
                historyStats: this.viewModel.historyStats,
                completionTimeStats: this.viewModel.completionTimeStats,
                overdueItems: this.viewModel.overdueItems,
                cardOrder: this.viewModel.overviewCardOrder,
                isMediumLayout: this.usesMediumLayout()
              })
            } else if (this.selectedIndexes[0] === 1) {
              TrendAnalysisSection({
                dailyStats: this.viewModel.dailyStats,
                monthlyStats: this.viewModel.monthlyStats,
                weeklyStats: this.viewModel.weeklyStats,
                contributionStats: this.viewModel.contributionStats,
                cardOrder: this.viewModel.trendCardOrder,
                isMediumLayout: this.usesMediumLayout()
              })
            } else if (this.selectedIndexes[0] === 2) {
              DashboardSection({
                metrics: this.viewModel.metrics,
                dailyStats: this.viewModel.lastMonthDailyStats,
                lastMonthName: this.viewModel.lastMonthName,
                analysis: this.viewModel.monthlyAnalysis,
                isAnalyzing: this.viewModel.isAnalyzing,
                isMediumLayout: this.usesMediumLayout()
              })
            }
          }
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
    .id(`overview_navigation_${this.currentThemeKey}`)
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: { mainTitle: '概览' },
        stackBuilder: () => {
          this.titleMenuBuilder();
        },
        bottomBuilder: {
          builder: () => {
            this.tabSegment();
          },
          height: this.SEGMENT_HEIGHT,
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        // divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .navBarWidth('100%')
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
