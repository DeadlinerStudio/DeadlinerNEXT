import { common, Want } from '@kit.AbilityKit';
import { MonthlyAnalysisResult } from '../ai/model/AIModels';
import { Metric } from './OverviewUtils';

export interface PaperTalkStatItem {
  label: string;
  value: string;
  highlight?: boolean;
}

export interface PaperTalkPayload {
  title: string;
  month: string;
  aiInsight: string;
  tags: string[];
  stats: PaperTalkStatItem[];
}

const PAPERTALK_BUNDLE_NAME: string = 'com.my.papertalk';
const PAPERTALK_ABILITY_NAME: string = 'EntryAbility';
const PAPERTALK_STORE_URI: string = 'store://appgallery.huawei.com/app/detail?id=com.my.papertalk';

export class PaperTalkUtils {
  static buildOverviewPayload(lastMonthName: string, analysis: MonthlyAnalysisResult | null,
    isAnalyzing: boolean, metrics: Metric[]): PaperTalkPayload {
    return {
      title: '数据汇总',
      month: lastMonthName,
      aiInsight: PaperTalkUtils.buildInsightText(lastMonthName, analysis, isAnalyzing),
      tags: PaperTalkUtils.buildInsightTags(analysis),
      stats: PaperTalkUtils.buildStats(metrics)
    };
  }

  static async openPrintOrStore(context: common.UIAbilityContext, payload: PaperTalkPayload): Promise<void> {
    const printWant: Want = {
      bundleName: PAPERTALK_BUNDLE_NAME,
      abilityName: PAPERTALK_ABILITY_NAME,
      parameters: {
        papertalk_action: 'print',
        papertalk_template: 'deadliner',
        papertalk_text: JSON.stringify(payload)
      }
    };

    try {
      await context.startAbility(printWant);
      return;
    } catch (error) {
      console.error(`[PaperTalkUtils] Open PaperTalk failed: ${JSON.stringify(error)}`);
    }

    const storeWant: Want = {
      action: 'ohos.want.action.appdetail',
      uri: PAPERTALK_STORE_URI
    };
    await context.startAbility(storeWant);
  }

  private static buildInsightText(lastMonthName: string, analysis: MonthlyAnalysisResult | null, isAnalyzing: boolean): string {
    if (analysis !== null && analysis.summary.length > 0) {
      return analysis.summary;
    }
    if (isAnalyzing) {
      return 'AI 正在分析你的上月表现，稍后会生成更完整的月度洞察。';
    }
    return `${lastMonthName}的数据已经整理好了，你可以先看看这些关键指标，稍后再生成更完整的 AI 洞察。`;
  }

  private static buildInsightTags(analysis: MonthlyAnalysisResult | null): string[] {
    if (analysis !== null && analysis.keywords.length > 0) {
      return analysis.keywords;
    }
    return ['月度回顾', '数据汇总', 'Deadliner'];
  }

  private static buildStats(metrics: Metric[]): PaperTalkStatItem[] {
    return metrics.map((metric: Metric): PaperTalkStatItem => {
      return {
        label: metric.label,
        value: metric.value,
        highlight: metric.label === '最活跃时段'
      };
    });
  }
}
