import { common } from '@kit.AbilityKit';
import { OverviewDashboardModel } from './OverviewDashboardModel';
import { OverviewViewModel } from './OverviewViewModel';
import { OverviewCalendarCard } from './OverviewCalendarCard';
import { OverviewPreviewChart } from './OverviewPreviewChart';
import { OverviewInsightCard } from './OverviewInsightCard';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { ITheme } from '../../../common/theme/ThemeModel';
import { DailyStat } from '../../../utils/OverviewUtils';
import { FocusDurationPoint } from './FocusStatisticsModels';
import { FocusPresentation } from '../focus/FocusPresentation';

@Component
export struct OverviewDashboardContent {
  @ObjectLink dashboard: OverviewDashboardModel;
  @ObjectLink model: OverviewViewModel;
  @Prop theme: ITheme;
  @State widthValue: number = 320;
  onOpen: (domain: string) => void = (_domain: string) => {};
  private counts(): number[] {
    const status = this.dashboard.state?.statusDistribution;
    return [status?.pending ?? 0, status?.completed ?? 0, status?.overdue ?? 0, status?.abandoned ?? 0];
  }
  private colors(): ResourceColor[] { return [this.theme.chartTodo, this.theme.chartCompleted, this.theme.chartOverdue, $r('app.color.font_secondary')]; }
  private labels: string[] = ['待办', '完成', '逾期', '放弃'];
  @Builder private managementCard(domain: string, title: string, value: string) {
    Column() {
    StatsCardContainer() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(title).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.font_secondary')])
        }.width('100%')
        Text(value).fontSize(22).fontWeight(FontWeight.Medium).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
    }.onClick(() => { this.onOpen(domain); }).accessibilityGroup(true).accessibilityText(title + ' ' + value)
  }
  @Builder private managementCards() {
    if (this.widthValue < 280 || (AppStorage.get<common.UIAbilityContext>('OverviewAbilityContext')?.config.fontSizeScale ?? 1) > 1.8) {
      Column({ space: 16 }) {
        this.managementCard('focus', '专注管理', this.model.focusError.length > 0 ? '暂不可用' : FocusPresentation.duration(this.model.focusStatistics?.today.totalDurationSeconds ?? 0))
        this.managementCard('archive', '归档', this.dashboard.archiveValue())
      }.width('100%')
    } else {
      Row({ space: 16 }) {
        Column() { this.managementCard('focus', '专注管理', this.model.focusError.length > 0 ? '暂不可用' : FocusPresentation.duration(this.model.focusStatistics?.today.totalDurationSeconds ?? 0)) }.layoutWeight(1)
        Column() { this.managementCard('archive', '归档', this.dashboard.archiveValue()) }.layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top)
    }
  }
  @Builder private taskCard() {
    Column() {
    StatsCardContainer() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('任务统计').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.font_secondary')])
        }.width('100%')
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text((this.dashboard.state?.completedCount ?? 0).toString() + ' 项').fontSize(26).fontWeight(FontWeight.Medium)
            Text(this.dashboard.comparisonText).fontSize(12).fontColor(this.dashboard.comparisonDelta > 0 ? this.theme.chartCompleted :
              this.dashboard.comparisonDelta < 0 ? this.theme.chartOverdue : $r('app.color.font_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          OverviewPreviewChart({ values: this.counts(), colors: this.colors(), kind: 'pie', description: '所选月任务状态分布' }).width(88).height(88)
        }.width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.labels, (label: string, index: number) => {
            Row({ space: 6 }) {
              Blank().width(6).height(6).backgroundColor(this.colors()[index]).borderRadius(3)
              Text(label + ' ' + this.counts()[index].toString()).fontSize(12).fontColor($r('app.color.font_secondary'))
            }.width('50%').padding({ top: 6 })
          }, (label: string) => label)
        }.width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
    }.onClick(() => { this.onOpen('tasks'); })
  }
  @Builder private trendCard() {
    Column() {
    StatsCardContainer() {
      Column({ space: 10 }) {
        Row() {
          Text('趋势').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          Text('最近 7 天').fontSize(12).fontColor($r('app.color.font_secondary'))
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.font_secondary')]).margin({ left: 8 })
        }.width('100%')
        Row({ space: 20 }) {
          Column({ space: 6 }) {
            Text('任务').fontSize(12).fontColor($r('app.color.font_secondary')).width('100%')
            OverviewPreviewChart({ values: this.model.dailyStats.slice(-7).map((day: DailyStat) => day.completed), colors: [this.theme.chartCompleted], description: '最近7天完成任务数量' }).height(72)
          }.layoutWeight(1)
          Column({ space: 6 }) {
            Text('专注').fontSize(12).fontColor($r('app.color.font_secondary')).width('100%')
            OverviewPreviewChart({ values: (this.model.focusStatistics?.daily ?? []).slice(-7).map((day: FocusDurationPoint) => day.durationSeconds),
              colors: [this.theme.chartInfo], kind: 'line', description: '最近7天已保存专注时长' }).height(72)
          }.layoutWeight(1)
        }.width('100%')
        if (this.model.focusError.length > 0) Text('专注趋势暂不可用').fontSize(12).fontColor($r('app.color.font_secondary'))
      }.width('100%')
    }
    }.onClick(() => { this.onOpen('trends'); })
  }
  build() {
    Column({ space: 16 }) {
      if (this.dashboard.loading && this.dashboard.state === null) LoadingProgress().width(32).height(32)
      if (this.dashboard.error.length > 0) {
        StatsCardContainer() {
          Text('月度数据加载失败').fontSize(14)
          Button('重试').onClick(() => { this.dashboard.load(); })
        }
      } else if (this.dashboard.state !== null) {
        OverviewCalendarCard({ model: this.dashboard, theme: this.theme })
      }
      this.managementCards()
      if (this.dashboard.state !== null && this.dashboard.error.length === 0) this.taskCard()
      if (this.model.loadError.length > 0) {
        StatsCardContainer() {
          Text(this.model.loadError).fontSize(14)
          Button('重试统计').onClick(() => { this.model.loadData(); })
        }
      } else if (this.model.isLoading) {
        LoadingProgress().width(28).height(28)
      } else {
        this.trendCard()
        OverviewInsightCard({ model: this.model, theme: this.theme, onOpen: () => { this.onOpen('review'); } })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .onAreaChange((_old: Area, area: Area) => { this.widthValue = Number(area.width); })
  }
}
