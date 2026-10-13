import { FocusDurationPoint, FocusOverviewStatistics, FocusStatisticsSummary } from './FocusStatisticsModels';
import { FocusPresentation } from '../focus/FocusPresentation';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { ContributionDay, DailyStat, MonthlyStat, WeeklyStat } from '../../../utils/OverviewUtils';
import { TrendCard } from './OverviewViewModel';
import { ITheme } from '../../../common/theme/ThemeModel';
import { ThemeManager } from '../../../common/theme/ThemeManager';
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { OverviewTrendChart } from './OverviewTrendChart';
import { OverviewContributionCard } from './OverviewContributionCard';
import { OverviewTrendPeriod, OverviewTrendPresentation } from './OverviewTrendPresentation';

@Component
export struct TrendAnalysisSection {
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  @StorageProp(C.KEY_OVERVIEW_SHOW_OVERDUE) showOverdue: boolean = true;
  @Prop focusStatistics: FocusOverviewStatistics | null = null;
  @Prop focusError: string = '';
  @Prop dailyStats: DailyStat[] = [];
  @Prop monthlyStats: MonthlyStat[] = [];
  @Prop weeklyStats: WeeklyStat[] = [];
  @Prop contributionStats: ContributionDay[] = [];
  @Prop cardOrder: TrendCard[] = [];
  onRetryFocus: () => void = () => {};

  private taskTotal(card: TrendCard): number {
    if (card === TrendCard.DAILY_TREND) return this.dailyStats.reduce((sum: number, day: DailyStat) => sum + day.completed, 0);
    if (card === TrendCard.MONTHLY_TREND) return this.monthlyStats.reduce((sum: number, month: MonthlyStat) => sum + month.completed, 0);
    return this.weeklyStats.reduce((sum: number, week: WeeklyStat) => sum + week.completed, 0);
  }
  private title(card: TrendCard): string {
    return card === TrendCard.DAILY_TREND ? '最近 7 天' : card === TrendCard.MONTHLY_TREND ? '每月趋势' : '近4周完成';
  }
  private period(card: TrendCard): OverviewTrendPeriod {
    return card === TrendCard.DAILY_TREND ? OverviewTrendPeriod.DAILY :
      card === TrendCard.MONTHLY_TREND ? OverviewTrendPeriod.MONTHLY : OverviewTrendPeriod.WEEKLY;
  }
  private points(card: TrendCard): FocusDurationPoint[] {
    if (card === TrendCard.DAILY_TREND) return this.focusStatistics?.daily ?? [];
    if (card === TrendCard.MONTHLY_TREND) return this.focusStatistics?.monthly ?? [];
    return this.focusStatistics?.rollingWeekly ?? [];
  }
  private summary(card: TrendCard): FocusStatisticsSummary | null {
    if (card === TrendCard.DAILY_TREND) return this.focusStatistics?.recentDaysSummary ?? null;
    if (card === TrendCard.MONTHLY_TREND) return this.focusStatistics?.recentMonthsSummary ?? null;
    return this.focusStatistics?.recentWeeksSummary ?? null;
  }
  private focusTotal(card: TrendCard): number {
    return this.summary(card)?.totalDurationSeconds ?? this.points(card).reduce((sum: number, point: FocusDurationPoint) => sum + point.durationSeconds, 0);
  }
  private breakdown(card: TrendCard): string {
    const split = this.summary(card)?.durationByTarget;
    if (split === undefined || split === null || split.habitDurationSeconds <= 0) return '';
    return '任务 ' + FocusPresentation.duration(split.taskDurationSeconds) + ' · 习惯 ' + FocusPresentation.duration(split.habitDurationSeconds);
  }
  @Builder private focusSection(card: TrendCard) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text('专注 · 分钟').fontSize(12).fontColor($r('app.color.font_secondary')).layoutWeight(1)
        Text(this.focusStatistics === null ? '—' : FocusPresentation.duration(this.focusTotal(card)))
          .fontSize(14).fontColor(this.theme.chartInfo)
      }.width('100%')
      if (this.focusError.length > 0) {
        Text('专注统计加载失败').fontSize(12).fontColor($r('app.color.font_secondary'))
        Button('重试专注统计').fontSize(12).onClick(this.onRetryFocus)
      } else if (this.focusStatistics === null) {
        Text('专注统计加载中…').fontSize(12).fontColor($r('app.color.font_secondary'))
      } else {
        if (this.breakdown(card).length > 0) Text(this.breakdown(card)).fontSize(12).fontColor($r('app.color.font_secondary')).width('100%')
        if (this.points(card).some((point: FocusDurationPoint) => point.durationSeconds > 0)) {
          OverviewTrendChart({ labels: OverviewTrendPresentation.focusLabels(this.points(card), this.period(card)),
            series: OverviewTrendPresentation.focusSeries(this.points(card), this.theme), line: card === TrendCard.MONTHLY_TREND,
            heightValue: 120, showLegend: false,
            description: this.points(card).map((point: FocusDurationPoint) => OverviewTrendPresentation.focusDetail(point)).join('; ') })
        } else {
          Text('这段时间暂无专注记录').fontSize(14).fontColor($r('app.color.font_secondary')).width('100%').padding({ top: 8, bottom: 8 })
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 12 })
  }
  @Builder private periodCard(card: TrendCard) {
    StatsCardContainer() {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text(this.title(card)).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          Text(this.taskTotal(card).toString() + ' 项').fontSize(12).fontColor($r('app.color.font_secondary'))
        }.width('100%')
        if (card === TrendCard.DAILY_TREND) {
          OverviewTrendChart({ labels: OverviewTrendPresentation.dailyLabels(this.dailyStats),
            series: OverviewTrendPresentation.dailySeries(this.dailyStats, this.theme, this.showOverdue),
            description: '最近7天任务完成和按到期日归属的逾期未完成数量' })
        } else if (card === TrendCard.MONTHLY_TREND) {
          OverviewTrendChart({ labels: OverviewTrendPresentation.monthlyLabels(this.monthlyStats),
            series: OverviewTrendPresentation.monthlySeries(this.monthlyStats, this.theme), line: true, heightValue: 180,
            description: '最近12个月全部任务、已完成和逾期完成数量' })
        } else {
          OverviewTrendChart({ labels: OverviewTrendPresentation.weeklyLabels(this.weeklyStats),
            series: OverviewTrendPresentation.weeklySeries(this.weeklyStats, this.theme), description: '最近4个滚动周已完成任务数量' })
        }
        this.focusSection(card)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
  build() {
    Column({ space: 16 }) {
      ForEach(this.cardOrder, (card: TrendCard) => {
        if (card === TrendCard.CONTRIBUTION_HEATMAP) OverviewContributionCard({ stats: this.contributionStats })
        else this.periodCard(card)
      }, (card: TrendCard) => card)
    }.width('100%').padding({ left: 16, right: 16 })
  }
}
