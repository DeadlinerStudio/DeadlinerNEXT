import { Metric } from '../../../utils/OverviewUtils';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles';
import { ThemeManager } from '../../../common/theme/ThemeManager';
import { ITheme } from '../../../common/theme/ThemeModel';
import { OverviewViewModel } from './OverviewViewModel';
import { OverviewStatsSection } from './OverviewStatsSection';
import { TrendAnalysisSection } from './TrendAnalysisSection';
import { MetricCard, LastMonthActivityMap } from './DashboardSection';
import { OverviewReviewExport } from './OverviewReviewExport';
import { OverviewInsightCard } from './OverviewInsightCard';
import { OverviewFocusManagement } from './OverviewFocusManagement';
import { MonthlyInsightRepository } from './MonthlyInsightRepository';
import { SortSheet } from './SortSheet';
import { OverviewTrendSettings } from './OverviewTrendSettings';
import { SheetCompat } from '../../../common/ui/SheetCompat';
import { HdsTitleBarMenuButton } from '../../components/HdsTitleBarMenuButton';
import { PaperTalkUtils } from '../../../utils/PaperTalkUtils';
import { Toast } from '../../../common/ui/Toast';
import { common } from '@kit.AbilityKit';
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';

@Component
export struct OverviewDetailPage {
  @Prop domain: string = 'tasks';
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  @StorageProp('FocusTimerActive') focusActive: boolean = false;
  @StorageProp(C.KEY_SHOW_PAPERTALK_SHARE) showPaperTalkShare: boolean = true;
  @StorageProp('FocusTimerRevision') @Watch('reload') focusRevision: number = 0;
  @StorageProp('KmpDataRevision') @Watch('reload') revision: number = 0;
  @StorageProp('IsAppDataReady') @Watch('reload') dataReady: boolean = false;
  @StorageProp('OverviewClockRevision') @Watch('reload') clockRevision: number = 0;
  @State model: OverviewViewModel = new OverviewViewModel();
  @State sortShown: boolean = false;
  @State shareShown: boolean = false;
  @State trendSettingsShown: boolean = false;
  @State sortAfterSettings: boolean = false;
  @StorageProp('OverviewAppForeground') @Watch('reload') foreground: boolean = true;
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { const context: Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) MonthlyInsightRepository.getInstance().init(context); this.reload(); }
  private reload(): void {
    if (!this.foreground || this.domain === 'focus') return;
    this.model.loadData();
  }
  private title(): string {
    if (this.domain === 'trends') return '趋势';
    if (this.domain === 'review') return '月度复盘';
    if (this.domain === 'focus') return '专注管理';
    return '任务统计';
  }
  private async share(): Promise<void> {
    const context: common.UIAbilityContext | undefined = AppStorage.get<common.UIAbilityContext>('OverviewAbilityContext');
    if (context === undefined) return;
    try {
      await PaperTalkUtils.openPrintOrStore(context, PaperTalkUtils.buildOverviewPayload(this.model.lastMonthName,
        this.model.monthlyAnalysis, this.model.isAnalyzing, this.model.metrics));
    } catch (_error) { Toast.show({ message: '暂时无法打开纸语或应用商店' }); }
  }
  @Builder private menu() {
    Row({ space: 8 }) {
      if (this.domain === 'trends') {
        HdsTitleBarMenuButton({ icon: $r('sys.symbol.slider_horizontal_2'), onButtonClick: () => { this.trendSettingsShown = true; } })
      }
      if (this.domain === 'tasks') {
        HdsTitleBarMenuButton({ icon: $r('sys.symbol.text_and_arrow_down'), onButtonClick: () => { this.sortShown = true; } })
      }
      if (this.domain === 'review') {
        HdsTitleBarMenuButton({ icon: $r('sys.symbol.share'), onButtonClick: () => { this.shareShown = true; } })
      }
    }.width('100%').height('100%').justifyContent(FlexAlign.End).padding({ right: 16 })
  }
  @Builder private exportSheet() {
    Scroll() {
      Column({ space: 12 }) {
        OverviewReviewExport({ model: this.model })
        if (this.showPaperTalkShare) Button('使用纸语分享').onClick(() => { this.share(); })
      }.width('100%').padding({ bottom: 32 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
  @Builder private trendSettings() {
    OverviewTrendSettings({ onClose: () => { this.trendSettingsShown = false; },
      onSort: () => { this.sortAfterSettings = true; this.trendSettingsShown = false; } })
  }
  @Builder private sortSheet() { SortSheet({ viewModel: $model, selectedTabIndex: this.domain === 'trends' ? 1 : 0, onClose: () => { this.sortShown = false; } }) }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.domain === 'focus') {
            OverviewFocusManagement()
          } else if (this.model.isLoading) {
            LoadingProgress().width(40).height(40)
          } else if (this.model.loadError.length > 0) {
            Text(this.model.loadError).fontSize(14)
            Button('重试').onClick(() => { this.reload(); })
          } else if (this.domain === 'tasks') {
            OverviewStatsSection({ todayCompleted: this.model.todayCompleted, todayTodo: this.model.todayTodo,
              todayOverdue: this.model.todayOverdue, activeAbandoned: this.model.activeAbandoned, historyStats: this.model.historyStats,
              completionTimeStats: this.model.completionTimeStats, overdueItems: this.model.overdueItems, cardOrder: this.model.overviewCardOrder })
          } else if (this.domain === 'trends') {
            TrendAnalysisSection({ focusStatistics: this.model.focusStatistics, focusError: this.model.focusError,
              dailyStats: this.model.dailyStats, monthlyStats: this.model.monthlyStats, weeklyStats: this.model.weeklyStats,
              contributionStats: this.model.contributionStats, cardOrder: this.model.trendCardOrder,
              onRetryFocus: () => { this.reload(); } })
          } else {
            Text('指标按截止日期月份统计；活动分布按完成日期统计。').fontSize(12).fontColor($r('app.color.font_secondary')).width('100%')
            OverviewInsightCard({ model: this.model, theme: this.theme, detail: true })
            Column({ space: 12 }) {
              ForEach(this.model.metrics, (metric: Metric) => {
                MetricCard({ metric: metric })
              }, (metric: Metric) => metric.label)
              LastMonthActivityMap({ monthName: this.model.lastMonthName, dailyStats: this.model.lastMonthDailyStats })
            }.width('100%')
          }
        }.width('100%').constraintSize({ maxWidth: 760 })
          .padding({ left: this.domain === 'tasks' || this.domain === 'trends' ? 0 : 16,
            right: this.domain === 'tasks' || this.domain === 'trends' ? 0 : 16,
            top: this.statusBarHeight + 18, bottom: this.focusActive ? 188 : 100 })
          .bindSheet($$this.shareShown, this.exportSheet(), SheetCompat.immersive({ height: SheetSize.LARGE, dragBar: true, title: { title: '复盘分享' } }))
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        .bindSheet($$this.trendSettingsShown, this.trendSettings(), SheetCompat.immersive({ height: SheetSize.FIT_CONTENT,
          dragBar: true, title: { title: '统计设置' }, onDisappear: () => {
            if (this.sortAfterSettings) { this.sortAfterSettings = false; this.sortShown = true; }
          } }))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }.titleBar({ style: getImmersiveTitleBarStyle(false), content: { title: { mainTitle: this.title(),
      subTitle: this.domain === 'review' ? this.model.lastMonthName : undefined }, stackBuilder: () => { this.menu(); } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .backgroundColor(this.theme.bgPrimary).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onShown(() => { this.reload(); })
      .bindSheet($$this.sortShown, this.sortSheet(), SheetCompat.immersive({ height: SheetSize.FIT_CONTENT, dragBar: true,
        title: { title: '调整卡片顺序', subtitle: '长按以拖动卡片标题' } }))
  }
}
@Builder export function OverviewTasksBuilder() { OverviewDetailPage({ domain: 'tasks' }) }
@Builder export function OverviewTrendsBuilder() { OverviewDetailPage({ domain: 'trends' }) }
@Builder export function OverviewReviewBuilder() { OverviewDetailPage({ domain: 'review' }) }
@Builder export function OverviewFocusBuilder() { OverviewDetailPage({ domain: 'focus' }) }
