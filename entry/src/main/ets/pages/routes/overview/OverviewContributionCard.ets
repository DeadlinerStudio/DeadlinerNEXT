import { ContributionDay } from '../../../utils/OverviewUtils';
import { StatsCardContainer } from '../../components/OverviewComponents';
import { ITheme } from '../../../common/theme/ThemeModel';
import { ThemeManager } from '../../../common/theme/ThemeManager';

@Component
export struct OverviewContributionCard {
  @StorageProp('currentTheme') theme: ITheme = ThemeManager.getCurrentTheme();
  @Prop stats: ContributionDay[] = [];
  @State gridWidth: number = 280;
  private weeks(): ContributionDay[][] {
    const result: ContributionDay[][] = [];
    for (let index: number = 0; index < this.stats.length; index += 7) result.push(this.stats.slice(index, index + 7));
    return result;
  }
  private cellSize(): number {
    const columns: number = Math.max(1, Math.ceil(this.stats.length / 7));
    return Math.max(1, Math.min(16, (this.gridWidth - 3 * (columns - 1)) / columns));
  }
  private cellOpacity(count: number): number { return count <= 0 ? 0.2 : count < 2 ? 0.3 : count < 4 ? 0.5 : count < 6 ? 0.72 : 1; }
  private dateLabel(day: ContributionDay): string {
    return day.date.getFullYear().toString() + '-' + (day.date.getMonth() + 1).toString().padStart(2, '0') + '-' +
      day.date.getDate().toString().padStart(2, '0') + ' 完成 ' + day.count.toString() + ' 项';
  }
  build() {
    StatsCardContainer() {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('活跃热力图').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
          Text(this.stats.length.toString() + '天内').fontSize(12).fontColor($r('app.color.font_secondary'))
        }.width('100%')
        if (this.stats.length > 0) {
          Row({ space: 3 }) {
            ForEach(this.weeks(), (week: ContributionDay[]) => {
              Column({ space: 3 }) {
                ForEach(week, (day: ContributionDay) => {
                  Blank().width(this.cellSize()).height(this.cellSize()).borderRadius(2)
                    .backgroundColor(day.count > 0 ? this.theme.chartCompleted : $r('app.color.font_secondary'))
                    .opacity(this.cellOpacity(day.count)).accessibilityText(this.dateLabel(day))
                }, (day: ContributionDay) => day.date.getTime().toString())
                if (week.length < 7) Blank().height((7 - week.length) * (this.cellSize() + 3) - 3)
              }.alignItems(HorizontalAlign.Start)
            }, (week: ContributionDay[]) => week[0].date.getTime().toString())
          }.width('100%').justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Top)
            .onAreaChange((_old: Area, area: Area) => { this.gridWidth = Number(area.width); })
          Row({ space: 4 }) {
            Text('少').fontSize(10).fontColor($r('app.color.font_secondary'))
            ForEach([0, 1, 3, 5, 7], (level: number) => {
              Blank().width(10).height(10).borderRadius(2).opacity(this.cellOpacity(level))
                .backgroundColor(level > 0 ? this.theme.chartCompleted : $r('app.color.font_secondary'))
            }, (level: number) => level.toString())
            Text('多').fontSize(10).fontColor($r('app.color.font_secondary'))
          }
        } else {
          Text('暂无数据').fontSize(14).fontColor($r('app.color.font_secondary')).width('100%').textAlign(TextAlign.Center).padding(24)
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
}
