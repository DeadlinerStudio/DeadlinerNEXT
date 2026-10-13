import { KmpPersistenceService } from '../../../common/kmp/KmpPersistenceService';
import { KmpOverviewDailyStat, KmpOverviewHistory, KmpOverviewLastMonth } from './KmpOverviewModels';
import { FocusStatisticsSnapshot } from './FocusStatisticsModels';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { DDLItem, Habit } from '../../../model/DDLModels';

export interface OverviewMonthState {
  monthStart: string;
  endDateExclusive: string;
  asOfDate: string;
  timeZoneId: string;
  completedCount: number;
  daily: KmpOverviewDailyStat[];
  review: KmpOverviewLastMonth;
  archivedTaskCount: number;
  archivedHabitCount: number;
  statusDistribution: KmpOverviewHistory;
}
export interface OverviewFocusRange { startDate: string; endDateExclusive: string; }
export interface OverviewFocusQuery { range?: OverviewFocusRange; }
export class OverviewMonthRules {
  static dateKey(date: Date): string {
    return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString().padStart(2, '0') + '-' + date.getDate().toString().padStart(2, '0');
  }
  static monthStart(date: Date = new Date()): string { return OverviewMonthRules.dateKey(new Date(date.getFullYear(), date.getMonth(), 1)); }
  static shift(month: string, distance: number): string {
    const date: Date = new Date(month + 'T00:00:00');
    return OverviewMonthRules.dateKey(new Date(date.getFullYear(), date.getMonth() + distance, 1));
  }
  static comparison(current: OverviewMonthState, previous: OverviewMonthState): number[] {
    const month: Date = new Date(current.monthStart + 'T00:00:00');
    const today: Date = new Date(current.asOfDate + 'T00:00:00');
    const cutoff: number = current.monthStart === OverviewMonthRules.monthStart(today) ? today.getDate() :
      new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const total: number = current.daily.filter((day: KmpOverviewDailyStat) => Number(day.date.substring(8, 10)) <= cutoff)
      .reduce((sum: number, day: KmpOverviewDailyStat) => sum + day.completedCount, 0);
    const prior: number = previous.daily.filter((day: KmpOverviewDailyStat) => Number(day.date.substring(8, 10)) <= cutoff)
      .reduce((sum: number, day: KmpOverviewDailyStat) => sum + day.completedCount, 0);
    return [total, prior];
  }
}

@Observed
export class OverviewDashboardModel {
  month: string = OverviewMonthRules.monthStart();
  state: OverviewMonthState | null = null;
  focus: FocusStatisticsSnapshot | null = null;
  loading: boolean = false;
  error: string = '';
  focusError: string = '';
  comparisonText: string = '';
  comparisonDelta: number = 0;
  archivedCount: number | null = null;
  archiveLoading: boolean = false;
  archiveError: string = '';
  private archiveRevision: number = 0;
  private revision: number = 0;

  async loadArchive(): Promise<void> {
    const token: number = ++this.archiveRevision;
    this.archiveLoading = true;
    this.archiveError = '';
    try {
      const tasks: DDLItem[] = await TaskRepository.getInstance().getArchivedDDLs();
      const habits: Habit[] = await HabitRepository.getInstance().getArchivedHabits();
      if (token === this.archiveRevision) this.archivedCount = tasks.length + habits.length;
    } catch (error) {
      if (token === this.archiveRevision) this.archiveError = String(error);
    } finally {
      if (token === this.archiveRevision) this.archiveLoading = false;
    }
  }
  archiveValue(): string {
    if (this.archivedCount !== null) return this.archivedCount.toString() + ' 项';
    return this.archiveError.length > 0 ? '加载失败' : '加载中';
  }

  async load(): Promise<void> {
    const token: number = ++this.revision;
    const month: string = this.month;
    this.loading = true;
    this.error = '';
    const core: KmpPersistenceService = KmpPersistenceService.getInstance();
    try {
      const current: OverviewMonthState = JSON.parse(core.overviewMonthJson(month));
      const previous: OverviewMonthState = JSON.parse(core.overviewMonthJson(OverviewMonthRules.shift(month, -1)));
      if (token !== this.revision) return;
      const comparison: number[] = OverviewMonthRules.comparison(current, previous);
      this.state = current;
      this.comparisonDelta = comparison[0] - comparison[1];
      this.comparisonText = this.comparisonDelta === 0 ? '较上月同期持平' : comparison[1] === 0 ?
        '较上月同期新增 ' + comparison[0].toString() + ' 项' : '较上月同期 ' +
        (this.comparisonDelta > 0 ? '↑ ' : '↓ ') + (Math.abs(this.comparisonDelta) * 100 / comparison[1]).toFixed(1) + '%';
    } catch (error) {
      if (token === this.revision) { this.state = null; this.error = String(error); }
    }
    try {
      const query: OverviewFocusQuery = { range: { startDate: month, endDateExclusive: OverviewMonthRules.shift(month, 1) } };
      const focus: FocusStatisticsSnapshot = JSON.parse(core.overviewFocusQueryJson(JSON.stringify(query)));
      if (token === this.revision) { this.focus = focus; this.focusError = ''; }
    } catch (error) {
      if (token === this.revision) { this.focus = null; this.focusError = String(error); }
    } finally {
      if (token === this.revision) this.loading = false;
    }
  }
  async switchMonth(distance: number): Promise<void> {
    const month: string = OverviewMonthRules.shift(this.month, distance);
    if (month > OverviewMonthRules.monthStart()) return;
    this.month = month;
    this.state = null;
    this.focus = null;
    await this.load();
  }
}
