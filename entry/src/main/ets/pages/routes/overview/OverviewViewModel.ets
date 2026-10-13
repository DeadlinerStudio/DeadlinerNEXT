import { MonthlyInsightRepository } from './MonthlyInsightRepository';
import { FocusOverviewStatistics } from './FocusStatisticsModels';
import { AppLog } from '../../../common/logging/AppLog';
import { LocalValues } from '../../../common/local/LocalValues';
import { DDLItem } from '../../../model/DDLModels';
import { AIService } from '../../../ai/AIServcice';
import { MonthlyAnalysisResult } from '../../../ai/model/AIModels';
import {
  DailyStat, MonthlyStat, WeeklyStat, ContributionDay,
  Metric
} from '../../../utils/OverviewUtils';
import { KmpPersistenceService } from '../../../common/kmp/KmpPersistenceService';
import {
  KmpOverviewCompletionBucket,
  KmpOverviewContributionDay,
  KmpOverviewDailyStat,
  KmpOverviewMonthlyMetrics,
  KmpOverviewMonthlyStat,
  KmpOverviewState,
  KmpOverviewStateReader,
  KmpOverviewWeeklyStat
} from './KmpOverviewModels';

// 1. 定义卡片 ID (为下一步拖拽排序做准备)
export enum OverviewCard {
  ACTIVE_STATS = 'ACTIVE_STATS',       // 今日概况
  COMPLETION_TIME = 'COMPLETION_TIME', // 完成时间分布
  HISTORY_STATS = 'HISTORY_STATS'      // 历史统计
}

export enum TrendCard {
  DAILY_TREND = 'DAILY_TREND',     // 本周完成
  MONTHLY_TREND = 'MONTHLY_TREND', // 每月趋势
  WEEKLY_TREND = 'WEEKLY_TREND',   // 近4周完成
  CONTRIBUTION_HEATMAP = 'CONTRIBUTION_HEATMAP' // 活跃热力图
}

@Observed
export class OverviewViewModel {
  // --- UI 状态 ---
  public isLoading: boolean = true;
  public focusStatistics: FocusOverviewStatistics | null = null;

  // --- Snapshot 数据 ---
  public todayCompleted: number = 0;
  public todayTodo: number = 0;
  public todayOverdue: number = 0;
  public activeAbandoned: number = 0;
  public historyStats: Map<string, number> = new Map();
  public completionTimeStats: Array<[string, number]> = [];
  public overdueItems: DDLItem[] = [];

  // --- Trend 数据 ---
  public dailyStats: DailyStat[] = [];
  public monthlyStats: MonthlyStat[] = [];
  public weeklyStats: WeeklyStat[] = [];
  public contributionStats: ContributionDay[] = [];

  // --- Dashboard 数据 ---
  public lastMonthDailyStats: DailyStat[] = [];
  public metrics: Metric[] = [];
  public lastMonthName: string = '';
  private lastMonthKey: string = '';
  public monthlyAnalysis: MonthlyAnalysisResult | null = null;
  public isAnalyzing: boolean = false;
  private analysisLoadToken: number = 0;
  public loadError: string = '';
  public focusError: string = '';
  private completedTaskTitles: string[] = [];

  // --- 排序配置 (为拖拽做准备，目前存默认顺序) ---
  public overviewCardOrder: OverviewCard[] = [
    OverviewCard.ACTIVE_STATS,
    OverviewCard.COMPLETION_TIME,
    OverviewCard.HISTORY_STATS
  ];

  public trendCardOrder: TrendCard[] = [
    TrendCard.CONTRIBUTION_HEATMAP,
    TrendCard.DAILY_TREND,
    TrendCard.MONTHLY_TREND,
    TrendCard.WEEKLY_TREND
  ];

  constructor() {
    this.loadSortOrder();
  }

  /**
   * 加载本地排序配置
   */
  private loadSortOrder() {
    const localVals = LocalValues.getInstance();

    // 读取概览页顺序
    const savedOverview = localVals.getOverviewCardOrder();
    if (savedOverview && savedOverview.length > 0) {
      // 强转 string[] 为 enum[] (只要存储时没存错字符串就行)
      this.overviewCardOrder = savedOverview as OverviewCard[];
    }

    // 读取趋势页顺序
    const savedTrend = localVals.getTrendCardOrder();
    if (savedTrend && savedTrend.length > 0) {
      this.trendCardOrder = this.normalizeTrendCardOrder(savedTrend);
    }
  }

  private normalizeTrendCardOrder(savedOrder: string[]): TrendCard[] {
    const normalized: TrendCard[] = [];
    const defaults: TrendCard[] = [
      TrendCard.CONTRIBUTION_HEATMAP,
      TrendCard.DAILY_TREND,
      TrendCard.MONTHLY_TREND,
      TrendCard.WEEKLY_TREND
    ];

    let index = 0;
    while (index < savedOrder.length) {
      const card: TrendCard | undefined = defaults.find((candidate: TrendCard) => candidate === savedOrder[index]);
      if (card !== undefined && !normalized.includes(card)) {
        normalized.push(card);
      }
      index += 1;
    }

    index = 0;
    while (index < defaults.length) {
      const card = defaults[index];
      if (!normalized.includes(card)) {
        normalized.push(card);
      }
      index += 1;
    }

    return normalized;
  }

  public async loadData() {
    this.isLoading = true;
    const loadToken = ++this.analysisLoadToken;
    this.loadError = '';
    try {
      this.focusStatistics = JSON.parse(KmpPersistenceService.getInstance().focusOverviewJson());
      this.focusError = '';
    } catch (error) { this.focusStatistics = null; this.focusError = String(error); }
    let completedTaskTitles: string[] | null = null;

    try {
      const payload: string = await KmpPersistenceService.getInstance().overviewViewModelJson();
      const state: KmpOverviewState = new KmpOverviewStateReader().parse(payload);
      if (state.error !== undefined && state.error !== null && state.error.length > 0) {
        throw new Error(state.error);
      }

      if (loadToken !== this.analysisLoadToken) return;
      this.todayCompleted = state.summary.completedToday;
      this.todayTodo = state.summary.pendingDueFromNow;
      this.todayOverdue = state.summary.overdueToday;
      this.activeAbandoned = state.summary.activeAbandoned;
      this.overdueItems = [];

      const newHistoryStats = new Map<string, number>();
      newHistoryStats.set('累计完成', state.history.completed);
      newHistoryStats.set('当前待办', state.history.pending);
      newHistoryStats.set('累计放弃', state.history.abandoned);
      newHistoryStats.set('累计逾期', state.history.overdue);
      this.historyStats = newHistoryStats;

      this.completionTimeStats = this.mapCompletionBuckets(state.completionBuckets);
      this.dailyStats = this.mapDailyStats(state.daily);
      this.monthlyStats = this.mapMonthlyStats(state.monthly);
      this.weeklyStats = this.mapWeeklyStats(state.weekly);
      this.contributionStats = this.mapContributionStats(state.contribution);
      this.lastMonthDailyStats = this.mapLastMonthDailyStats(state.lastMonth.daily);
      this.metrics = this.mapMetrics(state.lastMonth.metrics);
      const monthKey: string = state.lastMonth.monthStart?.substring(0, 7) ?? '';
      if (monthKey !== this.lastMonthKey) this.monthlyAnalysis = null;
      this.lastMonthKey = monthKey;
      this.lastMonthName = this.monthLabel(state.lastMonth.monthStart);
      completedTaskTitles = state.lastMonth.completedTaskTitles;
      this.completedTaskTitles = state.lastMonth.completedTaskTitles;
    } catch (e) {
      if (loadToken !== this.analysisLoadToken) return;
      this.loadError = '统计加载失败，请重试';
      AppLog.error('Native', '[OverviewViewModel] Load KMP state error: ' + String(e));
    } finally {
      if (loadToken === this.analysisLoadToken) this.isLoading = false;
    }

    if (completedTaskTitles !== null) {
      this.loadMonthlyAnalysisInBackground(completedTaskTitles, loadToken);
    }
  }

  private mapCompletionBuckets(items: KmpOverviewCompletionBucket[]): Array<[string, number]> {
    const result: Array<[string, number]> = [];
    for (const item of items) result.push([this.periodLabel(item.period), item.completedCount]);
    return result;
  }

  private mapDailyStats(items: KmpOverviewDailyStat[]): DailyStat[] {
    const result: DailyStat[] = [];
    for (const item of items) {
      const label: string = item.date.length >= 10 ? item.date.substring(5, 10) : item.date;
      const stat: DailyStat = {
        dateStr: label,
        fullDate: item.date,
        completed: item.completedCount,
        overdue: item.overdueCount
      };
      result.push(stat);
    }
    return result;
  }

  private mapMonthlyStats(items: KmpOverviewMonthlyStat[]): MonthlyStat[] {
    const result: MonthlyStat[] = [];
    for (const item of items) {
      const monthValue: number = item.monthStart.length >= 7 ? Number(item.monthStart.substring(5, 7)) : 0;
      const stat: MonthlyStat = {
        monthStr: monthValue.toString() + '月',
        total: item.totalCount,
        completed: item.completedCount,
        overdue: item.overdueCompletedCount
      };
      result.push(stat);
    }
    return result;
  }

  private mapLastMonthDailyStats(items: KmpOverviewDailyStat[]): DailyStat[] {
    const result: DailyStat[] = [];
    for (const item of items) {
      const label: string = item.date.length >= 10 ? item.date.substring(8, 10) : item.date;
      const stat: DailyStat = {
        dateStr: label,
        fullDate: item.date,
        completed: item.completedCount,
        overdue: item.overdueCount
      };
      result.push(stat);
    }
    return result;
  }

  private mapWeeklyStats(items: KmpOverviewWeeklyStat[]): WeeklyStat[] {
    const result: WeeklyStat[] = [];
    for (let index: number = 0; index < items.length; index += 1) {
      const label: string = items[index].weekStart.substring(5, 10);
      const stat: WeeklyStat = { weekLabel: label, completed: items[index].completedCount };
      result.push(stat);
    }
    return result;
  }

  private mapContributionStats(items: KmpOverviewContributionDay[]): ContributionDay[] {
    const result: ContributionDay[] = [];
    for (const item of items) {
      const day: ContributionDay = { date: new Date(item.date + 'T00:00:00'), count: item.completedCount };
      result.push(day);
    }
    return result;
  }

  private mapMetrics(metrics: KmpOverviewMonthlyMetrics): Metric[] {
    const result: Metric[] = [];
    result.push(this.comparisonMetric('上月任务数', metrics.totalTasks.toString(), metrics.totalTasks, metrics.previousTotalTasks));
    result.push(this.comparisonMetric('上月完成', metrics.completedTasks.toString(), metrics.completedTasks, metrics.previousCompletedTasks));
    result.push(this.comparisonMetric('上月完成率', metrics.completionRate.toFixed(1) + '%', metrics.completionRate, metrics.previousCompletionRate));
    result.push(this.comparisonMetric('上月逾期数', metrics.overdueTasks.toString(), metrics.overdueTasks, metrics.previousOverdueTasks));
    if (metrics.mostActivePeriod !== undefined && metrics.mostActivePeriod !== null) {
      const activeMetric: Metric = {
        label: '最活跃时段',
        value: this.periodLabel(metrics.mostActivePeriod),
        change: '完成 ' + metrics.mostActivePeriodCompletedCount.toString() + ' 个'
      };
      result.push(activeMetric);
    }
    if (metrics.averageCompletionMinutes !== undefined && metrics.averageCompletionMinutes !== null) {
      const minutes: number = metrics.averageCompletionMinutes;
      const duration: string = minutes < 60 ? minutes.toString() + ' 分钟' : (minutes / 60).toFixed(1) + ' 小时';
      const durationMetric: Metric = { label: '平均耗时', value: duration };
      result.push(durationMetric);
    }
    return result;
  }

  private comparisonMetric(label: string, value: string, current: number, previous: number): Metric {
    if (previous <= 0 || current === previous) return { label: label, value: value };
    const percent: string = (Math.abs(current - previous) / previous * 100).toFixed(1) + '%';
    return { label: label, value: value, change: percent, isDown: current < previous };
  }

  private periodLabel(period: string): string {
    if (period === 'OVERNIGHT') return '深夜';
    if (period === 'MORNING') return '上午';
    if (period === 'AFTERNOON') return '下午';
    return '晚上';
  }

  private monthLabel(monthStart?: string | null): string {
    if (monthStart === undefined || monthStart === null || monthStart.length < 7) return '';
    return monthStart.substring(0, 4) + '年' + Number(monthStart.substring(5, 7)).toString() + '月';
  }

  /**
   * 处理卡片移动并持久化
   */
  public onCardMove(tab: 'OVERVIEW' | 'TREND', from: number, to: number) {
    if (tab === 'OVERVIEW') {

      const newOrder = [...this.overviewCardOrder];
      // 2. 在新数组上操作
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      // 3. 重新赋值给属性 (这步是触发 @Link 刷新的关键)
      this.overviewCardOrder = newOrder;

      // 保存到本地
      LocalValues.getInstance().setOverviewCardOrder(this.overviewCardOrder);

    } else {
      // 趋势页同理
      const newOrder = [...this.trendCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.trendCardOrder = newOrder;

      LocalValues.getInstance().setTrendCardOrder(this.trendCardOrder);
    }
  }

  public moveItemInMemory(tab: 'OVERVIEW' | 'TREND', from: number, to: number) {
    if (from === to) return;

    if (tab === 'OVERVIEW') {
      const newOrder = [...this.overviewCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.overviewCardOrder = newOrder; // 触发 UI 刷新
    } else {
      const newOrder = [...this.trendCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.trendCardOrder = newOrder; // 触发 UI 刷新
    }
  }

  public saveCurrentOrder() {
    LocalValues.getInstance().setOverviewCardOrder(this.overviewCardOrder);
    LocalValues.getInstance().setTrendCardOrder(this.trendCardOrder);
  }

  private loadMonthlyAnalysisInBackground(completedTaskTitles: string[], loadToken: number): void {
    this.loadMonthlyAnalysis(completedTaskTitles, loadToken).catch((e: Error) => {
      AppLog.error('Native', '[OverviewViewModel] Background monthly analysis error: ' + e.message);
    });
  }

  public async loadMonthlyAnalysis(completedTaskTitles: string[], loadToken: number, retry: boolean = false): Promise<void> {
    const monthKey: string = this.lastMonthKey;
    this.isAnalyzing = true;
    const result: MonthlyAnalysisResult | null = await MonthlyInsightRepository.getInstance().load(
      monthKey, this.lastMonthName, this.metrics, completedTaskTitles, retry);
    if (loadToken === this.analysisLoadToken) {
      this.monthlyAnalysis = result;
      this.isAnalyzing = false;
    }
  }

  public retryMonthlyAnalysis(): void {
    this.loadMonthlyAnalysis(this.completedTaskTitles, this.analysisLoadToken, true);
  }

}
