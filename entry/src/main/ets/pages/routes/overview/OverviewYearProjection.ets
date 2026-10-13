import { KmpPersistenceService } from '../../../common/kmp/KmpPersistenceService';
import { OverviewMonthRules, OverviewMonthState } from './OverviewDashboardModel';
import { ContributionDay } from '../../../utils/OverviewUtils';

/** Reuse Core daily projections to show this calendar year, rather than extending the legacy 150-day projection with invented values. */
export class OverviewYearProjection {
  static load(): ContributionDay[] {
    const today: Date = new Date();
    const todayKey: string = OverviewMonthRules.dateKey(today);
    const result: ContributionDay[] = [];
    const core: KmpPersistenceService = KmpPersistenceService.getInstance();
    for (let month: number = 0; month <= today.getMonth(); month++) {
      const key: string = OverviewMonthRules.monthStart(new Date(today.getFullYear(), month, 1));
      const state: OverviewMonthState = JSON.parse(core.overviewMonthJson(key));
      for (const day of state.daily) {
        if (day.date <= todayKey) result.push({ date: new Date(day.date + 'T00:00:00'), count: day.completedCount });
      }
    }
    return result;
  }
}
