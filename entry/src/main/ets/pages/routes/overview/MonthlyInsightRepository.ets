import { preferences } from '@kit.ArkData';
import { LocalValues } from '../../../common/local/LocalValues';
import { MonthlyAnalysisResult } from '../../../ai/model/AIModels';
import { AIService } from '../../../ai/AIServcice';
import { Metric } from '../../../utils/OverviewUtils';
import { OverviewMonthRules } from './OverviewDashboardModel';

/** Application-owned promises outlive cards and destinations. Persist attempts before invoking AI. */
export class MonthlyInsightRepository {
  private static instance: MonthlyInsightRepository = new MonthlyInsightRepository();
  private store: preferences.Preferences | null = null;
  private requests: Map<string, Promise<MonthlyAnalysisResult | null>> = new Map();
  static getInstance(): MonthlyInsightRepository { return MonthlyInsightRepository.instance; }
  init(context: Context): void {
    try {
      if (this.store === null) this.store = preferences.getPreferencesSync(context, { name: 'overview_monthly_reviews' });
    } catch (_error) { this.store = null; }
  }
  private decode(raw: string, month: string): MonthlyAnalysisResult | null {
    if (raw.length === 0) return null;
    try {
      const result: MonthlyAnalysisResult = JSON.parse(raw);
      return result.month === month && result.summary.trim().length > 0 && Array.isArray(result.keywords) ? result : null;
    } catch (_error) { return null; }
  }
  load(month: string, name: string, metrics: Metric[], titles: string[], retry: boolean = false): Promise<MonthlyAnalysisResult | null> {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || month >= OverviewMonthRules.monthStart().substring(0, 7)) return Promise.resolve(null);
    const pending: Promise<MonthlyAnalysisResult | null> | undefined = this.requests.get(month);
    if (pending !== undefined) return pending;
    const request: Promise<MonthlyAnalysisResult | null> = this.resolve(month, name, metrics, titles, retry);
    this.requests.set(month, request);
    request.finally(() => { this.requests.delete(month); });
    return request;
  }
  private async resolve(month: string, name: string, metrics: Metric[], titles: string[], retry: boolean): Promise<MonthlyAnalysisResult | null> {
    try {
      const store: preferences.Preferences | null = this.store;
      if (store === null) return null;
      const raw: preferences.ValueType = store.getSync('analysis/' + month, '');
      const cached: MonthlyAnalysisResult | null = this.decode(String(raw), month);
      if (cached !== null) return cached;
      const legacy: MonthlyAnalysisResult | null = this.decode(LocalValues.getInstance().getMonthlyAnalysis(), month);
      if (legacy !== null) {
        store.putSync('analysis/' + month, JSON.stringify(legacy));
        try { await store.flush(); }
        catch (error) { store.deleteSync('analysis/' + month); throw new Error('旧月度洞察迁移失败：' + String(error)); }
        return legacy;
      }
      if (store.getSync('attempted/' + month, false) === true && !retry) return null;
      if (LocalValues.getInstance().getDeepSeekApiKey().length === 0) return null;
      store.putSync('attempted/' + month, true);
      await store.flush();
      const summary: string = metrics.map((metric: Metric) => metric.label + ': ' + metric.value).join('\n');
      const generated: MonthlyAnalysisResult = await AIService.getInstance().generateMonthlyAnalysis(name, summary, titles);
      if (generated.summary.trim().length === 0) return null;
      const result: MonthlyAnalysisResult = { month: month, summary: generated.summary, keywords: generated.keywords,
        generatedAt: generated.generatedAt || new Date().toISOString() };
      store.putSync('analysis/' + month, JSON.stringify(result));
      try { await store.flush(); }
      catch (error) { store.deleteSync('analysis/' + month); throw new Error('月度洞察保存失败：' + String(error)); }
      return result;
    } catch (_error) { return null; }
  }
}
