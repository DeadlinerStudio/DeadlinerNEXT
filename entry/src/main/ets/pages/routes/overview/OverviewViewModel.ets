import { LocalValues } from '../../../common/local/LocalValues';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DDLItem, DeadlineType, isTaskAbandonedState } from '../../../model/DDLModels';
import { AIService } from '../../../ai/AIServcice';
import { MonthlyAnalysisResult } from '../../../ai/model/AIModels';
import {
  safeParseOptionalDate, extractTimeBucket,
  computeDailyCompletedCounts, computeMonthlyTaskStats, computeWeeklyCompletedCounts,
  computeContributionStats, computeLastMonthDailyStats,
  DailyStat, MonthlyStat, WeeklyStat, ContributionDay,
  generateDashboardMetrics, Metric
} from '../../../utils/OverviewUtils';

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
  public allItems: DDLItem[] = []; // Dashboard 需要原始数据
  public lastMonthDailyStats: DailyStat[] = [];
  public metrics: Metric[] = [];
  public lastMonthName: string = '';
  public monthlyAnalysis: MonthlyAnalysisResult | null = null;
  public isAnalyzing: boolean = false;
  private analysisLoadToken: number = 0;

  // --- 排序配置 (为拖拽做准备，目前存默认顺序) ---
  public overviewCardOrder: OverviewCard[] = [
    OverviewCard.ACTIVE_STATS,
    OverviewCard.COMPLETION_TIME,
    OverviewCard.HISTORY_STATS
  ];

  public trendCardOrder: TrendCard[] = [
    TrendCard.DAILY_TREND,
    TrendCard.MONTHLY_TREND,
    TrendCard.WEEKLY_TREND,
    TrendCard.CONTRIBUTION_HEATMAP
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
      this.trendCardOrder = this.normalizeTrendCardOrder(savedTrend as TrendCard[]);
    }
  }

  private normalizeTrendCardOrder(savedOrder: TrendCard[]): TrendCard[] {
    const normalized: TrendCard[] = [];
    const defaults: TrendCard[] = [
      TrendCard.DAILY_TREND,
      TrendCard.MONTHLY_TREND,
      TrendCard.WEEKLY_TREND,
      TrendCard.CONTRIBUTION_HEATMAP
    ];

    let index = 0;
    while (index < savedOrder.length) {
      const card = savedOrder[index];
      if (defaults.includes(card) && !normalized.includes(card)) {
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

  // 原封不动搬运过来的数据加载逻辑
  public async loadData() {
    this.isLoading = true;
    const loadToken = ++this.analysisLoadToken;
    let loadedItems: DDLItem[] | null = null;

    try {
      const items = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);
      loadedItems = items;
      this.allItems = items;
      this.dailyStats = computeDailyCompletedCounts(items, 7);
      this.monthlyStats = computeMonthlyTaskStats(items, 12);
      this.weeklyStats = computeWeeklyCompletedCounts(items, 4);
      this.contributionStats = computeContributionStats(items, 150);
      this.lastMonthDailyStats = computeLastMonthDailyStats(items);
      this.metrics = generateDashboardMetrics(items);
      this.lastMonthName = this.buildLastMonthName();

      const now = new Date();
      const bucketCounts = new Map<string, number>();
      bucketCounts.set('深夜', 0);
      bucketCounts.set('上午', 0);
      bucketCounts.set('下午', 0);
      bucketCounts.set('晚上', 0);

      const overdueItems: DDLItem[] = [];
      let completedToday: number = 0;
      let todayTodo: number = 0;
      let todayOverdue: number = 0;
      let activeAbandoned: number = 0;
      let historyCompleted: number = 0;
      let historyAbandoned: number = 0;
      let historyIncomplete: number = 0;
      let historyOverdue: number = 0;

      let index: number = 0;
      while (index < items.length) {
        const item = items[index];
        const endDate = safeParseOptionalDate(item.endTime);
        const completeDate = safeParseOptionalDate(item.completeTime);
        const isAbandoned = isTaskAbandonedState(item.state);

        if (item.isCompleted) {
          historyCompleted += 1;
          if (completeDate !== null) {
            const bucket = extractTimeBucket(item.completeTime);
            bucketCounts.set(bucket, (bucketCounts.get(bucket) || 0) + 1);
            if (!item.isArchived && this.isSameDay(completeDate, now)) {
              completedToday += 1;
            }
          }
        } else if (isAbandoned) {
          historyAbandoned += 1;
          if (!item.isArchived) {
            activeAbandoned += 1;
          }
        } else {
          historyIncomplete += 1;
        }

        if (!item.isArchived && !item.isCompleted && !isAbandoned && endDate !== null) {
          if (endDate.getTime() >= now.getTime()) {
            todayTodo += 1;
          } else {
            historyOverdue += 1;
            overdueItems.push(item);
            if (this.isSameDay(endDate, now)) {
              todayOverdue += 1;
            }
          }
        }

        index += 1;
      }

      this.todayCompleted = completedToday;
      this.todayTodo = todayTodo;
      this.todayOverdue = todayOverdue;
      this.activeAbandoned = activeAbandoned;
      this.overdueItems = overdueItems;

      const newHistoryStats = new Map<string, number>();
      newHistoryStats.set('累计完成', historyCompleted);
      newHistoryStats.set('当前待办', historyIncomplete);
      newHistoryStats.set('累计放弃', historyAbandoned);
      newHistoryStats.set('累计逾期', historyOverdue);
      this.historyStats = newHistoryStats;

      this.completionTimeStats = [
        ['深夜', bucketCounts.get('深夜') || 0],
        ['上午', bucketCounts.get('上午') || 0],
        ['下午', bucketCounts.get('下午') || 0],
        ['晚上', bucketCounts.get('晚上') || 0]
      ];

    } catch (e) {
      console.error(`[OverviewViewModel] Load data error: ${e}`);
    } finally {
      this.isLoading = false;
    }

    if (loadedItems !== null) {
      this.loadMonthlyAnalysisInBackground(loadedItems, loadToken);
    }
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

  private loadMonthlyAnalysisInBackground(items: DDLItem[], loadToken: number): void {
    this.loadMonthlyAnalysis(items, loadToken).catch((e: Error) => {
      console.error(`[OverviewViewModel] Background monthly analysis error: ${e}`);
    });
  }

  public async loadMonthlyAnalysis(items: DDLItem[], loadToken: number): Promise<void> {
    const monthKey = this.buildPreviousMonthKey();
    if (loadToken !== this.analysisLoadToken) {
      return;
    }
    this.monthlyAnalysis = null;
    this.isAnalyzing = false;
    const cached = LocalValues.getInstance().getMonthlyAnalysis();
    if (cached && cached.length > 0) {
      try {
        const parsed = JSON.parse(cached) as MonthlyAnalysisResult;
        if (parsed.month === monthKey && loadToken === this.analysisLoadToken) {
          this.monthlyAnalysis = parsed;
          return;
        }
      } catch (e) {
        console.error(`[OverviewViewModel] Decode monthly analysis error: ${e}`);
      }
    }

    await this.generateMonthlyAnalysis(items, monthKey, this.lastMonthName, loadToken);
  }

  public async generateMonthlyAnalysis(items: DDLItem[], monthKey: string, monthLabel: string, loadToken: number): Promise<void> {
    if (this.isAnalyzing || loadToken !== this.analysisLoadToken) {
      return;
    }

    const apiKey = LocalValues.getInstance().getDeepSeekApiKey();
    if (!apiKey || apiKey.length === 0) {
      return;
    }

    this.isAnalyzing = true;
    try {
      const range = this.buildLastMonthRange();
      const lastMonthItems = items.filter((item: DDLItem) => {
        const endDate = safeParseOptionalDate(item.endTime);
        return endDate !== null &&
          endDate.getTime() >= range[0].getTime() &&
          endDate.getTime() <= range[1].getTime();
      });

      const completedTaskNames = lastMonthItems
        .filter((item: DDLItem) => item.isCompleted)
        .map((item: DDLItem) => item.name);
      const metricsSummary = this.metrics
        .map((metric: Metric) => `${metric.label}: ${metric.value} (${metric.change || '无变化'})`)
        .join('\n');

      const result = await AIService.getInstance().generateMonthlyAnalysis(
        monthLabel,
        metricsSummary,
        completedTaskNames
      );
      const finalResult: MonthlyAnalysisResult = {
        month: monthKey,
        summary: result.summary,
        keywords: result.keywords,
        generatedAt: result.generatedAt || new Date().toISOString()
      };
      if (loadToken !== this.analysisLoadToken) {
        return;
      }
      this.monthlyAnalysis = finalResult;
      await LocalValues.getInstance().setMonthlyAnalysis(JSON.stringify(finalResult));
      await LocalValues.getInstance().setLastAnalyzedMonth(monthKey);
    } catch (e) {
      console.error(`[OverviewViewModel] Generate monthly analysis error: ${e}`);
    } finally {
      this.isAnalyzing = false;
    }
  }

  private isSameDay(left: Date, right: Date): boolean {
    return left.getFullYear() === right.getFullYear() &&
      left.getMonth() === right.getMonth() &&
      left.getDate() === right.getDate();
  }

  private buildPreviousMonthKey(): string {
    const now = new Date();
    const firstDayOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const firstDayOfLastMonth = new Date(firstDayOfThisMonth.getFullYear(), firstDayOfThisMonth.getMonth() - 1, 1);
    const year = firstDayOfLastMonth.getFullYear();
    const month = `${firstDayOfLastMonth.getMonth() + 1}`.padStart(2, '0');
    return `${year}-${month}`;
  }

  private buildLastMonthName(): string {
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    return `${lastMonth.getMonth() + 1}月`;
  }

  private buildLastMonthRange(): [Date, Date] {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
    return [start, end];
  }
}
