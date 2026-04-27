import { DDLItem } from '../model/DDLModels';

export function hashColor(key: string): ResourceColor {
  if (key.includes('今日') || key.includes('完成')) return $r('app.color.chart_green'); // Green
  if (key.includes('未完成')) return $r('app.color.chart_orange'); // Orange
  if (key.includes('逾期')) return $r('app.color.chart_red'); // Red
  return $r('app.color.chart_blue'); // Blue
}

export function safeParseDate(dateStr: string): Date {
  const parsed = safeParseOptionalDate(dateStr);
  if (parsed !== null) {
    return parsed;
  }
  return new Date();
}

export function safeParseOptionalDate(dateStr: string): Date | null {
  if (!dateStr || dateStr.length === 0) {
    return null;
  }
  try {
    const date = new Date(dateStr);
    if (!isNaN(date.getTime())) {
      return date;
    }
    const fallback = new Date(dateStr.replace(/-/g, '/'));
    if (!isNaN(fallback.getTime())) {
      return fallback;
    }
  } catch (e) {
  }
  return null;
}

export function isOverdue(item: DDLItem): boolean {
  try {
    const end = safeParseDate(item.endTime);
    const now = new Date();
    return !item.isCompleted && (now.getTime() > end.getTime());
  } catch (e) {
    return false;
  }
}

export function isToday(dateStr: string): boolean {
  const d = safeParseDate(dateStr);
  const now = new Date();
  return d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
}

export function extractTimeBucket(completeTime: string): string {
  try {
    const time = safeParseDate(completeTime);
    const hour = time.getHours();
    if (hour >= 0 && hour < 6) return '深夜';
    if (hour >= 6 && hour < 12) return '上午';
    if (hour >= 12 && hour < 18) return '下午';
    if (hour >= 18 && hour <= 23) return '晚上';
    return '未知';
  } catch (e) {
    return '未知';
  }
}

// 时间段排序权重
export const bucketOrder: Record<string, number> = {
  '深夜': 0,
  '上午': 1,
  '下午': 2,
  '晚上': 3,
  '未知': 4
};

export interface DailyStat {
  dateStr: string;   // e.g., "12", "13" (日)
  fullDate: string;  // e.g., "2023-12-12" (用于调试或唯一key)
  completed: number;
  overdue: number;
}

export interface MonthlyStat {
  monthStr: string; // e.g., "2023-10"
  total: number;
  completed: number;
  overdue: number;
}

export interface WeeklyStat {
  weekLabel: string; // e.g., "第42周"
  completed: number;
}

export interface ContributionDay {
  date: Date;
  count: number;
}

// --- 3. 核心统计逻辑 (移植自 Android) ---

/**
 * 计算过去 days 天的每日完成和逾期情况
 */
export function computeDailyCompletedCounts(items: DDLItem[], days: number = 7): DailyStat[] {
  const result: DailyStat[] = [];
  const today = new Date();
  const now = new Date();
  const completedMap = new Map<string, number>();
  const overdueMap = new Map<string, number>();

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    const completedDate = safeParseOptionalDate(item.completeTime);
    if (item.isCompleted && completedDate !== null) {
      const completedKey = dayKey(completedDate);
      const completedCount = completedMap.get(completedKey) || 0;
      completedMap.set(completedKey, completedCount + 1);
    }

    const endDate = safeParseOptionalDate(item.endTime);
    if (!item.isCompleted && endDate !== null && endDate.getTime() < now.getTime()) {
      const overdueKey = dayKey(endDate);
      const overdueCount = overdueMap.get(overdueKey) || 0;
      overdueMap.set(overdueKey, overdueCount + 1);
    }
    index += 1;
  }

  for (let i = days - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setDate(today.getDate() - i);
    const key = dayKey(targetDate);

    result.push({
      dateStr: `${targetDate.getMonth() + 1}`.padStart(2, '0') + '-' + `${targetDate.getDate()}`.padStart(2, '0'),
      fullDate: targetDate.toDateString(),
      completed: completedMap.get(key) || 0,
      overdue: overdueMap.get(key) || 0
    });
  }
  return result;
}

/**
 * 计算过去 months 个月的任务趋势
 */
export function computeMonthlyTaskStats(items: DDLItem[], months: number = 6): MonthlyStat[] {
  const result: MonthlyStat[] = [];
  const today = new Date();
  const totalMap = new Map<string, number>();
  const completedMap = new Map<string, number>();
  const overdueCompletedMap = new Map<string, number>();

  let itemIndex = 0;
  while (itemIndex < items.length) {
    const item = items[itemIndex];
    const endDate = safeParseOptionalDate(item.endTime);
    if (endDate !== null) {
      const key = monthKey(endDate);
      totalMap.set(key, (totalMap.get(key) || 0) + 1);

      if (item.isCompleted) {
        completedMap.set(key, (completedMap.get(key) || 0) + 1);

        const completeDate = safeParseOptionalDate(item.completeTime);
        if (completeDate !== null && completeDate.getTime() > endDate.getTime()) {
          overdueCompletedMap.set(key, (overdueCompletedMap.get(key) || 0) + 1);
        }
      }
    }
    itemIndex += 1;
  }

  for (let i = months - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setDate(1);
    targetDate.setMonth(today.getMonth() - i);
    const key = monthKey(targetDate);
    const month = targetDate.getMonth() + 1;

    result.push({
      monthStr: `${month}月`,
      total: totalMap.get(key) || 0,
      completed: completedMap.get(key) || 0,
      overdue: overdueCompletedMap.get(key) || 0
    });
  }
  return result;
}

/**
 * 计算过去 weeks 周的完成数
 */
export function computeWeeklyCompletedCounts(items: DDLItem[], weeks: number = 4): WeeklyStat[] {
  const result: WeeklyStat[] = [];
  const today = new Date();
  for (let i = weeks - 1; i >= 0; i--) {
    const endOfWeek = new Date(today);
    endOfWeek.setDate(today.getDate() - i * 7);
    const startOfWeek = new Date(endOfWeek);
    startOfWeek.setDate(endOfWeek.getDate() - 6);
    setStartOfDay(startOfWeek);
    setEndOfDay(endOfWeek);

    let count = 0;
    let itemIndex = 0;
    while (itemIndex < items.length) {
      const item = items[itemIndex];
      if (item.isCompleted) {
        const completeDate = safeParseOptionalDate(item.completeTime);
        if (completeDate !== null &&
          completeDate.getTime() >= startOfWeek.getTime() &&
          completeDate.getTime() <= endOfWeek.getTime()) {
          count += 1;
        }
      }
      itemIndex += 1;
    }

    let label = '本周';
    if (i > 0) {
      label = `${i}周前`;
    }

    result.push({
      weekLabel: label,
      completed: count
    });
  }
  return result;
}

export function computeContributionStats(items: DDLItem[], days: number = 150): ContributionDay[] {
  const result: ContributionDay[] = [];
  const today = new Date();
  const completedMap = new Map<string, number>();

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    if (item.isCompleted) {
      const completeDate = safeParseOptionalDate(item.completeTime);
      if (completeDate !== null) {
        const key = dayKey(completeDate);
        completedMap.set(key, (completedMap.get(key) || 0) + 1);
      }
    }
    index += 1;
  }

  for (let i = days - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setDate(today.getDate() - i);
    const key = dayKey(targetDate);
    result.push({
      date: targetDate,
      count: completedMap.get(key) || 0
    });
  }
  return result;
}

export function computeLastMonthDailyStats(items: DDLItem[]): DailyStat[] {
  const result: DailyStat[] = [];
  const now = new Date();
  const firstDayOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const firstDayOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const completedMap = new Map<string, number>();
  const overdueMap = new Map<string, number>();

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    const completedDate = safeParseOptionalDate(item.completeTime);
    if (item.isCompleted && completedDate !== null) {
      const completedKey = dayKey(completedDate);
      completedMap.set(completedKey, (completedMap.get(completedKey) || 0) + 1);
    }

    const endDate = safeParseOptionalDate(item.endTime);
    if (!item.isCompleted && endDate !== null && endDate.getTime() < now.getTime()) {
      const overdueKey = dayKey(endDate);
      overdueMap.set(overdueKey, (overdueMap.get(overdueKey) || 0) + 1);
    }
    index += 1;
  }

  const cursor = new Date(firstDayOfLastMonth);
  while (cursor.getTime() < firstDayOfThisMonth.getTime()) {
    const key = dayKey(cursor);
    result.push({
      dateStr: `${cursor.getDate()}`,
      fullDate: cursor.toDateString(),
      completed: completedMap.get(key) || 0,
      overdue: overdueMap.get(key) || 0
    });
    cursor.setDate(cursor.getDate() + 1);
  }

  return result;
}

// --- 4. Dashboard 统计逻辑 (移植自 Android) ---

export interface Metric {
  label: string;
  value: string;
  change?: string;     // 变化量文本 (e.g., "12", "5%")
  isDown?: boolean;    // true=下降(红色), false=上升(绿色), null=持平(蓝色/无色)
}

interface MonthStats {
  total: number;
  completed: number;
  rate: number;
  overdue: number;
}

// 获取上个月的起始和结束时间
export function getLastMonthRange(): [Date, Date] {
  const now = new Date();
  // 设为本月1号
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  // 设为本月0号 (即上个月最后一天) 23:59:59
  const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
  return [start, end];
}

// 获取前上个月 (上上个月) 的起始和结束时间
export function getPrevMonthRange(): [Date, Date] {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - 2, 1);
  const end = new Date(now.getFullYear(), now.getMonth() - 1, 0, 23, 59, 59);
  return [start, end];
}

// 统计特定时间段的数据
function collectStatsInRange(items: DDLItem[], start: Date, end: Date): MonthStats {
  let total = 0;
  let completed = 0;
  let overdue = 0;

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    const endDate = safeParseOptionalDate(item.endTime);
    if (endDate !== null &&
      endDate.getTime() >= start.getTime() &&
      endDate.getTime() <= end.getTime()) {
      total += 1;
      if (item.isCompleted) {
        completed += 1;
      } else {
        overdue += 1;
      }
    }
    index += 1;
  }

  let rate = 0;
  if (total > 0) {
    rate = completed / total * 100;
  }

  return { total, completed, rate, overdue };
}

function computePercentageChange(current: number, previous: number): [string | undefined, boolean | undefined] {
  if (previous <= 0) {
    return [undefined, undefined];
  }
  const diff = current - previous;
  if (diff === 0) {
    return [undefined, undefined];
  }
  const percent = Math.abs(diff) / previous * 100;
  return [`${percent.toFixed(1)}%`, diff < 0];
}

function formatRate(rate: number): string {
  return `${rate.toFixed(1)}%`;
}

function formatAverageDuration(items: DDLItem[], start: Date, end: Date): string | null {
  let totalSeconds = 0;
  let count = 0;

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    const endDate = safeParseOptionalDate(item.endTime);
    if (endDate !== null &&
      endDate.getTime() >= start.getTime() &&
      endDate.getTime() <= end.getTime() &&
      item.isCompleted) {
      const startDate = safeParseOptionalDate(item.startTime);
      const completeDate = safeParseOptionalDate(item.completeTime);
      if (startDate !== null && completeDate !== null && completeDate.getTime() >= startDate.getTime()) {
        totalSeconds += (completeDate.getTime() - startDate.getTime()) / 1000;
        count += 1;
      }
    }
    index += 1;
  }

  if (count === 0) {
    return null;
  }

  const averageSeconds = totalSeconds / count;
  const minutes = Math.floor(averageSeconds / 60);
  if (minutes < 60) {
    return `${minutes} 分钟`;
  }
  return `${(minutes / 60).toFixed(1)} 小时`;
}

function findTopCompletionBucket(items: DDLItem[], start: Date, end: Date): string | null {
  const bucketMap = new Map<string, number>();

  let index = 0;
  while (index < items.length) {
    const item = items[index];
    const endDate = safeParseOptionalDate(item.endTime);
    if (item.isCompleted &&
      endDate !== null &&
      endDate.getTime() >= start.getTime() &&
      endDate.getTime() <= end.getTime()) {
      const completeDate = safeParseOptionalDate(item.completeTime);
      if (completeDate !== null) {
        const bucket = extractTimeBucket(item.completeTime);
        bucketMap.set(bucket, (bucketMap.get(bucket) || 0) + 1);
      }
    }
    index += 1;
  }

  const bucketNames = ['深夜', '上午', '下午', '晚上'];
  let bestBucket: string | null = null;
  let bestCount = 0;
  let bucketIndex = 0;
  while (bucketIndex < bucketNames.length) {
    const bucketName = bucketNames[bucketIndex];
    const bucketCount = bucketMap.get(bucketName) || 0;
    if (bucketCount > bestCount) {
      bestCount = bucketCount;
      bestBucket = bucketName;
    }
    bucketIndex += 1;
  }

  return bestBucket;
}

// --- 核心入口：生成 Dashboard 指标列表 ---
export function generateDashboardMetrics(items: DDLItem[]): Metric[] {
  const lastMonthRange = getLastMonthRange();
  const lastStart = lastMonthRange[0];
  const lastEnd = lastMonthRange[1];
  const prevMonthRange = getPrevMonthRange();
  const prevStart = prevMonthRange[0];
  const prevEnd = prevMonthRange[1];

  const lastStats = collectStatsInRange(items, lastStart, lastEnd);
  const prevStats = collectStatsInRange(items, prevStart, prevEnd);

  const totalChange = computePercentageChange(lastStats.total, prevStats.total);
  const completedChange = computePercentageChange(lastStats.completed, prevStats.completed);
  const rateChange = computePercentageChange(lastStats.rate, prevStats.rate);
  const overdueChange = computePercentageChange(lastStats.overdue, prevStats.overdue);
  const activeBucket = findTopCompletionBucket(items, lastStart, lastEnd);
  const averageDuration = formatAverageDuration(items, lastStart, lastEnd);

  const metrics: Metric[] = [];
  metrics.push({
    label: '上月任务数',
    value: `${lastStats.total}`,
    change: totalChange[0],
    isDown: totalChange[1]
  });
  metrics.push({
    label: '上月完成',
    value: `${lastStats.completed}`,
    change: completedChange[0],
    isDown: completedChange[1]
  });
  metrics.push({
    label: '上月完成率',
    value: formatRate(lastStats.rate),
    change: rateChange[0],
    isDown: rateChange[1]
  });
  metrics.push({
    label: '上月逾期数',
    value: `${lastStats.overdue}`,
    change: overdueChange[0],
    isDown: overdueChange[1]
  });
  if (activeBucket !== null) {
    const bucketCount = countCompletedTasksInBucket(items, lastStart, lastEnd, activeBucket);
    metrics.push({
      label: '最活跃时段',
      value: activeBucket,
      change: `完成 ${bucketCount} 个`
    });
  }
  if (averageDuration !== null) {
    metrics.push({
      label: '平均耗时',
      value: averageDuration
    });
  }
  return metrics;
}

function countCompletedTasksInBucket(items: DDLItem[], start: Date, end: Date, bucket: string): number {
  let count = 0;
  let index = 0;
  while (index < items.length) {
    const item = items[index];
    if (item.isCompleted) {
      const endDate = safeParseOptionalDate(item.endTime);
      if (endDate !== null &&
        endDate.getTime() >= start.getTime() &&
        endDate.getTime() <= end.getTime() &&
        extractTimeBucket(item.completeTime) === bucket) {
        count += 1;
      }
    }
    index += 1;
  }
  return count;
}

function dayKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function monthKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  return `${year}-${month}`;
}

function setStartOfDay(date: Date): void {
  date.setHours(0, 0, 0, 0);
}

function setEndOfDay(date: Date): void {
  date.setHours(23, 59, 59, 999);
}
