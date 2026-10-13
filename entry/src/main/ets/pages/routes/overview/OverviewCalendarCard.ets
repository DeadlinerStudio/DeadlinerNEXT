import { StatsCardContainer } from '../../components/OverviewComponents';
import { OverviewDashboardModel, OverviewMonthRules } from './OverviewDashboardModel';
import { KmpOverviewDailyStat } from './KmpOverviewModels';
import { FocusDurationPoint } from './FocusStatisticsModels';
import { FocusPresentation } from '../focus/FocusPresentation';
import { ITheme } from '../../../common/theme/ThemeModel';

@Component
export struct OverviewCalendarCard {
  @ObjectLink model: OverviewDashboardModel;
  @Prop theme: ITheme;
  private weekdays: string[] = ['一', '二', '三', '四', '五', '六', '日'];
  private cells(): number[] {
    const first: Date = new Date(this.model.month + 'T00:00:00');
    const offset: number = (first.getDay() + 6) % 7;
    const days: number = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    const result: number[] = [];
    for (let index: number = 0; index < Math.ceil((offset + days) / 7) * 7; index++) {
      result.push(index >= offset && index < offset + days ? index - offset + 1 : 0);
    }
    return result;
  }
  private dayKey(day: number): string { return this.model.month.substring(0, 8) + day.toString().padStart(2, '0'); }
  private completed(day: number): number {
    return this.model.state?.daily.find((item: KmpOverviewDailyStat) => item.date === this.dayKey(day))?.completedCount ?? 0;
  }
  private focus(day: number): number {
    return this.model.focus?.daily.find((item: FocusDurationPoint) => item.startDate === this.dayKey(day))?.durationSeconds ?? 0;
  }
  private available(day: number): boolean { return day > 0 && this.dayKey(day) <= OverviewMonthRules.dateKey(new Date()); }
  private showDay(day: number): void {
    this.getUIContext().showAlertDialog({
      title: this.dayKey(day), message: '完成任务 ' + this.completed(day).toString() + ' 项\n已保存专注 ' +
        (this.model.focusError.length > 0 ? '暂时不可用' : FocusPresentation.duration(this.focus(day))),
      confirm: { value: '知道了', action: () => {} }
    });
  }
  build() {
    StatsCardContainer() {
      Column({ space: 10 }) {
        Text('月度活动').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.font_primary')).width('100%')
        Row({ space: 4 }) {
          ForEach(this.weekdays, (day: string) => {
            Text(day).fontSize(11).fontColor($r('app.color.font_secondary')).layoutWeight(1).textAlign(TextAlign.Center)
          }, (day: string) => day)
        }.width('100%')
        Grid() {
          ForEach(this.cells(), (day: number, index: number) => {
            GridItem() {
              if (day > 0) {
                Button({ type: ButtonType.Normal }) {
                  Stack({ alignContent: Alignment.Bottom }) {
                    Text(day.toString()).fontSize(12).fontColor($r('app.color.font_primary')).margin({ bottom: 7 })
                    if (this.focus(day) > 0) Blank().width(4).height(4).backgroundColor(this.theme.chartInfo).borderRadius(2).margin({ bottom: 3 })
                  }.height(32).width('100%')
                }
                .height(32).width('100%').padding(0).borderRadius(8)
                .backgroundColor(this.completed(day) === 0 ? $r('app.color.background_primary') : this.theme.chartCompleted)
                .opacity(!this.available(day) ? 0.3 : this.completed(day) === 0 ? 1 : Math.min(1, 0.35 + this.completed(day) * 0.16))
                .enabled(this.available(day)).onClick(() => { this.showDay(day); })
                .accessibilityText(this.dayKey(day) + ' 完成 ' + this.completed(day).toString() + ' 项')
              }
            }
          }, (_day: number, index: number) => this.model.month + '-' + index.toString())
        }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').columnsGap(4).rowsGap(4)
          .height(Math.ceil(this.cells().length / 7) * 36 - 4).width('100%')
        Text('颜色深浅表示完成数量 · 蓝点表示已保存专注').fontSize(11).fontColor($r('app.color.font_secondary')).width('100%')
        if (this.model.focusError.length > 0) {
          Button('重试专注数据').fontSize(12).onClick(() => { this.model.load(); })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
}
