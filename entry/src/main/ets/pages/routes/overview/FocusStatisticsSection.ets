import { FocusOverviewStatistics } from './FocusStatisticsModels';
import { FocusDurationChart, FocusTimeBrief } from './FocusDurationChart';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { FocusPresentation } from '../focus/FocusPresentation';

@Component
export struct FocusStatisticsSection {
  @Prop statistics: FocusOverviewStatistics | null = null;
  @Prop mode: string = 'overview';
  build() {
    Column({ space: 8 }) {
      if (this.statistics !== null) {
        if (this.mode === 'overview') {
          StatsCardContainer() {
            Text('今日专注').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            Text(FocusPresentation.duration(this.statistics.today.totalDurationSeconds)).fontSize(28).fontWeight(FontWeight.Bold).width('100%')
            FocusTimeBrief({ summary: this.statistics.today })
            Text(this.statistics.today.sessionCount.toString() + ' 次 · 本周 ' + FocusPresentation.duration(this.statistics.thisWeek.totalDurationSeconds)).fontSize(12)
          }
          StatsCardContainer() {
            Text('累计专注').fontSize(16).width('100%')
            Text(FocusPresentation.duration(this.statistics.allTime.totalDurationSeconds)).fontSize(24).width('100%')
            FocusTimeBrief({ summary: this.statistics.allTime })
          }
        } else if (this.mode === 'trend') {
          FocusDurationChart({ title: '近 7 天专注', points: this.statistics.daily, summary: this.statistics.recentDaysSummary })
          FocusDurationChart({ title: '近 6 月专注', points: this.statistics.monthly.slice(-6) })
          FocusDurationChart({ title: '近 4 周专注', points: this.statistics.rollingWeekly, summary: this.statistics.recentWeeksSummary })
        } else {
          StatsCardContainer() {
            Text('上月专注').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            Text(FocusPresentation.duration(this.statistics.lastMonth.current.summary.totalDurationSeconds)).fontSize(28).width('100%')
            FocusTimeBrief({ summary: this.statistics.lastMonth.current.summary })
            Text(this.statistics.lastMonth.current.summary.activeDayCount.toString() + ' 个专注日').fontSize(12)
          }
          FocusDurationChart({ title: '每日专注', points: this.statistics.lastMonth.current.daily, summary: this.statistics.lastMonth.current.summary })
        }
      }
    }.width('100%')
  }
}
