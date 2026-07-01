import { common } from '@kit.AbilityKit';
import { LocalValues } from '../common/local/LocalValues';
import { DirectProvider } from './core/DirectProvider';
import { DeadlinerCoreService } from './core/DeadlinerCoreService';
import { LLMProvider } from './core/LLMProvider';
import { ChatRequest, Message, MixedResult, AITask, AIHabit, AIToolResult, MonthlyAnalysisResult } from './model/AIModels';
import { MemoryBank } from './model/MemoryModels';

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

  private getProvider(): LLMProvider {
    const local = LocalValues.getInstance();
    const apiKey = local.getDeepSeekApiKey(); // 根据你的 LocalValues 实际方法名调整
    const baseUrl = local.getAIBaseUrl();

    if (!apiKey) {
      throw new Error('请先在设置中填写 API Key');
    }
    return new DirectProvider(apiKey, baseUrl);
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
  // MARK: - Legacy APIs (Extract Tasks/Habits)
  // ==========================================

  public async extractTasks(text: string, preferredLang: string = 'zh-CN'): Promise<AITask[]> {
    const systemPrompt = this.buildTaskSystemPrompt(preferredLang);
    const messages: Message[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const content = await this.fetchFromProvider(messages);
    console.info('[AIService] Legacy Extract Tasks Raw Response:', content);

    const jsonString = this.extractJsonData(content);
    const resultObj = JSON.parse(jsonString) as MixedResult;
    return resultObj.tasks ?? [];
  }

  public async extractHabits(text: string, preferredLang: string = 'zh-CN'): Promise<AIHabit[]> {
    const systemPrompt = this.buildHabitSystemPrompt(preferredLang);
    const messages: Message[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const content = await this.fetchFromProvider(messages);
    console.info('[AIService] Legacy Extract Habits Raw Response:', content);

    const jsonString = this.extractJsonData(content);
    const resultObj = JSON.parse(jsonString) as MixedResult;
    return resultObj.habits ?? [];
  }

  public async generateMonthlyAnalysis(
    monthName: string,
    metricsSummary: string,
    completedTaskNames: string[]
  ): Promise<MonthlyAnalysisResult> {
    const tasksStr = completedTaskNames.slice(0, 50).join(', ');
    const systemPrompt = `
你是 Lifi AI 数据分析专家。请根据用户上个月（${monthName}）的任务完成数据，生成一份简短的月度总结和一组关键词标签。

要求：
1. 总结要口语化、温暖且有洞察力。
2. 总结字数在 80-120 字左右。
3. 提取 5-10 个关键词标签，并尽量深度结合“上月完成任务名”体现的主题。
4. 关键词要有代表性，适合用于词云或标签展示。

必须输出纯 JSON：
{
  "month": "${monthName}",
  "summary": "...",
  "keywords": ["标签1", "标签2", "标签3", "标签4", "标签5"]
}
`;

    const userContent = `
指标数据：
${metricsSummary}

上月完成的部分任务名：
${tasksStr}
`;

    const messages: Message[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent }
    ];

    const content = await this.fetchFromProvider(messages);
    console.info('[AIService] Monthly Analysis Raw Response:', content);

    const jsonString = this.extractJsonData(content);
    const result = JSON.parse(jsonString) as MonthlyAnalysisResult;
    return {
      month: result.month || monthName,
      summary: result.summary || '',
      keywords: result.keywords || [],
      generatedAt: result.generatedAt || new Date().toISOString()
    };
  }

  // ==========================================
  // MARK: - Networking Wrapper
  // ==========================================

  private async fetchFromProvider(messages: Message[]): Promise<string> {
    const provider = this.getProvider();
    const modelId = LocalValues.getInstance().getAIModel() || "deepseek-chat";

    const request: ChatRequest = {
      model: modelId,
      messages: messages,
      temperature: 0.1
    };

    try {
      const response = await provider.chat(request);
      const content = response.choices[0]?.message?.content;
      if (!content) {
        throw new Error('AI 返回内容为空');
      }
      return content;
    } catch (err) {
      console.error('[AIService] Fetch failed:', JSON.stringify(err));
      throw new Error(err);
    }
  }

  // ==========================================
  // MARK: - JSON Extraction (鲁棒解析)
  // ==========================================

  private extractJsonData(raw: string): string {
    const cleaned = this.stripCodeFence(raw);

    if (this.isLikelyJsonObject(cleaned)) {
      return cleaned;
    }

    const extracted = this.extractFirstJsonObject(cleaned);
    if (extracted) {
      return extracted;
    }

    throw new Error("AI 数据解析失败: 未找到有效的 JSON 对象");
  }

  private stripCodeFence(str: string): string {
    let s = str.trim();
    if (s.startsWith("```json")) s = s.substring(7);
    else if (s.startsWith("```")) s = s.substring(3);

    if (s.endsWith("```")) s = s.substring(0, s.length - 3);
    return s.trim();
  }

  private isLikelyJsonObject(s: string): boolean {
    const t = s.trim();
    return t.startsWith("{") && t.endsWith("}");
  }

  private extractFirstJsonObject(s: string): string | null {
    const start = s.indexOf("{");
    if (start === -1) return null;

    let depth = 0;
    let inString = false;
    let escape = false;

    for (let i = start; i < s.length; i++) {
      const c = s[i];

      if (inString) {
        if (escape) escape = false;
        else if (c === "\\") escape = true;
        else if (c === '"') inString = false;
        continue;
      } else {
        if (c === '"') { inString = true; continue; }
        if (c === "{") depth += 1;
        if (c === "}") depth -= 1;
        if (depth === 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  // ==========================================
  // MARK: - Prompt Builders
  // ==========================================
  private buildTaskSystemPrompt(preferredLang: string): string {
    const now = this.isoNowString();
    const offset = -(new Date().getTimezoneOffset() / 60);
    const tz = `UTC${offset >= 0 ? '+' : ''}${offset}`;

    return `你是 Lifi AI 的任务提取器。
【当前时间】${now}
【当前时区】${tz}
【用户语言】${preferredLang}

只输出纯 JSON。

- name：2-8字最佳，不超过15字；去冗词。
- note：细节补充；无则 ""。
- dueTime：必须严格 "yyyy-MM-dd HH:mm" 或 ""；
  若用户给了日期/相对日期但无时刻：按规则补齐默认时刻（上午09:00/中午12:00/下午15:00/晚上20:00；无时段词默认09:00）。
  若用户明确不确定时间：""。

返回：
{"primaryIntent":"ExtractTasks","tasks":[{"name":"","dueTime":"yyyy-MM-dd HH:mm","note":""}]}
`;
  }

  private buildHabitSystemPrompt(preferredLang: string): string {
    const now = this.isoNowString();
    const offset = -(new Date().getTimezoneOffset() / 60);
    const tz = `UTC${offset >= 0 ? '+' : ''}${offset}`;

    return `你是 Lifi AI 的习惯提取器。
【当前时间】${now}
【当前时区】${tz}
【用户语言】${preferredLang}

只输出纯 JSON。

- name：2-8字
- period：只能 "DAILY"/"WEEKLY"/"MONTHLY"，未提及默认 "DAILY"
- timesPerPeriod：整数，未提及默认 1
- goalType：只能 "PER_PERIOD"/"TOTAL"，默认 "PER_PERIOD"
- totalTarget：仅当 goalType="TOTAL" 时给整数，否则不要返回该字段

返回：
{"primaryIntent":"ExtractHabits","habits":[{"name":"","period":"DAILY","timesPerPeriod":1,"goalType":"PER_PERIOD"}]}
`;
  }

  private isoNowString(): string {
    // 对齐 iOS 的 ISO8601 输出
    return new Date().toISOString();
  }
}
