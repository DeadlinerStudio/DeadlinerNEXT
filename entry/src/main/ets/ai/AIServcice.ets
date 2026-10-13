import { common } from '@kit.AbilityKit';
import { DeadlinerCoreService } from './core/DeadlinerCoreService';
import { MixedResult, AITask, AIHabit, AIToolResult, MonthlyAnalysisResult } from './model/AIModels';

export class AIService {
  private static instance: AIService;
  private coreService: DeadlinerCoreService = DeadlinerCoreService.getInstance();

  private constructor() {}

  public static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  public async init(context: common.Context): Promise<void> {
    await this.coreService.init(context);
  }

  // ==========================================
  // MARK: - Agent Core (Intent + Content + Memory)
  // ==========================================

  public async processInput(
    text: string,
    preferredLang: string = "zh-CN",
    sessionContext: string = "",
    sessionSummary: string = ""
  ): Promise<MixedResult> {
    return this.coreService.processInput(text);
  }

  // ==========================================
  // MARK: - Agent Continue (after tool result)
  // ==========================================

  public async continueAfterTool(
    originalUserText: string,
    toolResult: AIToolResult,
    preferredLang: string = "zh-CN",
    sessionContext: string = "",
    sessionSummary: string = ""
  ): Promise<MixedResult> {
    return this.coreService.submitToolResult(toolResult);
  }

  // ==========================================
  // MARK: - KMP AI utilities
  // ==========================================

  public async extractQuickAddJson(request: string): Promise<string> {
    return this.coreService.extractQuickAddJson(request);
  }

  public async extractTasks(text: string, preferredLang: string = 'zh-CN'): Promise<AITask[]> {
    return this.coreService.extractTasks(text, preferredLang);
  }

  public async extractHabits(text: string, preferredLang: string = 'zh-CN'): Promise<AIHabit[]> {
    return this.coreService.extractHabits(text, preferredLang);
  }

  public async generateMonthlyAnalysis(
    monthName: string,
    metricsSummary: string,
    completedTaskNames: string[]
  ): Promise<MonthlyAnalysisResult> {
    return this.coreService.generateMonthlyAnalysis(monthName, metricsSummary, completedTaskNames);
  }
}
