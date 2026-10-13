import { DailyStat, MonthlyStat, WeeklyStat } from '../../../utils/OverviewUtils';
import { ITheme } from '../../../common/theme/ThemeModel';
import { FocusDurationPoint } from './FocusStatisticsModels';

export enum OverviewTrendPeriod { DAILY = 'daily', MONTHLY = 'monthly', WEEKLY = 'weekly' }
export class OverviewTrendSeries {
  label: string;
  values: number[];
  color: ResourceColor;
  details: string[];
  constructor(label: string, values: number[], color: ResourceColor, details: string[]) {
    this.label = label; this.values = values; this.color = color; this.details = details;
  }
}

/** Maps shared projections to chart labels; never aggregates task dates on the UI side. */
export class OverviewTrendPresentation {
  static dailyLabels(stats: DailyStat[]): string[] {
    return stats.map((day: DailyStat) => Number(day.fullDate.substring(8, 10)).toString());
  }
  static dailySeries(stats: DailyStat[], theme: ITheme, showOverdue: boolean): OverviewTrendSeries[] {
    const result: OverviewTrendSeries[] = [new OverviewTrendSeries('已完成', stats.map((day: DailyStat) => day.completed),
      theme.chartCompleted, stats.map((day: DailyStat) => day.fullDate + '\n已完成 ' + day.completed.toString() + ' 项'))];
    if (showOverdue) result.push(new OverviewTrendSeries('逾期未完成', stats.map((day: DailyStat) => day.overdue),
      theme.chartOverdue, stats.map((day: DailyStat) => day.fullDate + '\n逾期未完成 ' + day.overdue.toString() + ' 项')));
    return result;
  }
  static monthlyLabels(stats: MonthlyStat[]): string[] {
    return stats.map((month: MonthlyStat) => month.monthStr.replace('月', ''));
  }
  static monthlySeries(stats: MonthlyStat[], theme: ITheme): OverviewTrendSeries[] {
    return [
      new OverviewTrendSeries('全部任务', stats.map((month: MonthlyStat) => month.total), theme.chartInfo,
        stats.map((month: MonthlyStat) => month.monthStr + '\n全部任务 ' + month.total.toString() + ' 项')),
      new OverviewTrendSeries('已完成', stats.map((month: MonthlyStat) => month.completed), theme.chartCompleted,
        stats.map((month: MonthlyStat) => month.monthStr + '\n已完成 ' + month.completed.toString() + ' 项')),
      new OverviewTrendSeries('逾期完成', stats.map((month: MonthlyStat) => month.overdue), theme.chartTodo,
        stats.map((month: MonthlyStat) => month.monthStr + '\n逾期完成 ' + month.overdue.toString() + ' 项'))
    ];
  }
  static weeklyLabels(stats: WeeklyStat[]): string[] { return stats.map((week: WeeklyStat) => week.weekLabel); }
  static weeklySeries(stats: WeeklyStat[], theme: ITheme): OverviewTrendSeries[] {
    return [new OverviewTrendSeries('已完成', stats.map((week: WeeklyStat) => week.completed), theme.chartTodo,
      stats.map((week: WeeklyStat) => week.weekLabel + '\n已完成 ' + week.completed.toString() + ' 项'))];
  }
  static focusLabels(points: FocusDurationPoint[], period: OverviewTrendPeriod): string[] {
    return points.map((point: FocusDurationPoint) => period === OverviewTrendPeriod.WEEKLY ? point.startDate.substring(5, 10) :
      Number(point.startDate.substring(period === OverviewTrendPeriod.MONTHLY ? 5 : 8, period === OverviewTrendPeriod.MONTHLY ? 7 : 10)).toString());
  }
  static preciseDuration(raw: number): string {
    const seconds: number = Math.max(0, Math.floor(raw));
    const hours: number = Math.floor(seconds / 3600);
    const minutes: number = Math.floor(seconds % 3600 / 60);
    return (hours > 0 ? hours.toString() + ' 小时 ' : '') + (minutes > 0 ? minutes.toString() + ' 分 ' : '') +
      (seconds % 60).toString() + ' 秒';
  }
  static focusDetail(point: FocusDurationPoint): string {
    const end: Date = new Date(point.endDateExclusive + 'T00:00:00');
    end.setDate(end.getDate() - 1);
    const endKey: string = end.getFullYear().toString() + '-' + (end.getMonth() + 1).toString().padStart(2, '0') + '-' + end.getDate().toString().padStart(2, '0');
    const period: string = point.startDate === endKey ? point.startDate : point.startDate + ' – ' + endKey;
    const split = point.durationByTarget;
    return period + '\n专注 ' + OverviewTrendPresentation.preciseDuration(point.durationSeconds) +
      (split !== null && split.habitDurationSeconds > 0 ? '\n任务 ' + OverviewTrendPresentation.preciseDuration(split.taskDurationSeconds) +
        '\n习惯 ' + OverviewTrendPresentation.preciseDuration(split.habitDurationSeconds) : '');
  }
  static focusSeries(points: FocusDurationPoint[], theme: ITheme): OverviewTrendSeries[] {
    return [new OverviewTrendSeries('专注 · 分钟', points.map((point: FocusDurationPoint) => point.durationSeconds / 60),
      theme.chartInfo, points.map((point: FocusDurationPoint) => OverviewTrendPresentation.focusDetail(point)))];
  }
}
