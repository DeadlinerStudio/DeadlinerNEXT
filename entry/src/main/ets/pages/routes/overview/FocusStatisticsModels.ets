export interface FocusDurationBreakdown { taskDurationSeconds: number; habitDurationSeconds: number; }
export interface FocusStatisticsSummary {
  totalDurationSeconds: number; sessionCount: number; taskCount: number; habitCount: number;
  activeDayCount: number; averageSessionDurationSeconds: number; durationByTarget: FocusDurationBreakdown | null;
}
export interface FocusDurationPoint {
  startDate: string; endDateExclusive: string; durationSeconds: number; sessionCount: number;
  durationByTarget: FocusDurationBreakdown | null;
}
export interface FocusStatisticsSnapshot { summary: FocusStatisticsSummary; daily: FocusDurationPoint[]; }
export interface FocusMonthlyReview {
  current: FocusStatisticsSnapshot; previousSummary: FocusStatisticsSummary;
  durationChangeSeconds: number; durationChangePercent: number | null;
}
export interface FocusOverviewStatistics {
  asOfDate: string; timeZoneId: string; today: FocusStatisticsSummary; thisWeek: FocusStatisticsSummary;
  allTime: FocusStatisticsSummary; daily: FocusDurationPoint[]; monthly: FocusDurationPoint[];
  rollingWeekly: FocusDurationPoint[]; lastMonth: FocusMonthlyReview;
  recentDaysSummary: FocusStatisticsSummary | null; recentMonthsSummary: FocusStatisticsSummary | null;
  recentWeeksSummary: FocusStatisticsSummary | null;
}
