import { LocalValues } from '../common/local/LocalValues';
import { DirectProvider } from './core/DirectProvider';
import { LLMProvider } from './core/LLMProvider';
import { ChatRequest, Message, MixedResult, AITask, AIHabit, AIToolResult, MonthlyAnalysisResult } from './model/AIModels';
import { MemoryBank } from './model/MemoryModels';

export class AIService {
  private static instance: AIService;

  private constructor() {}

  public static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
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
    const memoryBank = MemoryBank.getInstance();
    const longTerm = memoryBank.getLongTermContext();

    const systemPrompt = this.buildAgentSystemPrompt(
      preferredLang,
      longTerm,
      sessionSummary,
      sessionContext
    );

    const messages: Message[] = [
      { role: "system", content: systemPrompt },
      { role: "user", content: text }
    ];

    const content = await this.fetchFromProvider(messages);
    console.info("[AIService] Raw Response:", content);

    const jsonString = this.extractJsonData(content);
    const result = JSON.parse(jsonString) as MixedResult;

    // 1. 处理新提取的记忆
    if (result.newMemories && result.newMemories.length > 0) {
      const filtered = this.filterMemories(result.newMemories, result, text);
      for (const mem of filtered) {
        await memoryBank.saveMemory(mem, "Auto-Extracted");
      }
    }

    // 2. 更新用户画像
    if (result.userProfile && result.userProfile.trim().length > 0) {
      await memoryBank.saveUserProfile(result.userProfile);
    }

    return result;
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
    const memoryBank = MemoryBank.getInstance();
    const longTerm = memoryBank.getLongTermContext();

    const toolHint = `
    你正在进行二段对话（工具结果已提供）。
    - 不要再次请求 readTasks（除非用户明确要求刷新/再查）。
    - 你可以基于工具结果输出新的 tasks/habits proposal（用于新增/补全/纠错），但必须避免重复已存在任务。
    `;

    const systemPrompt = this.buildAgentSystemPrompt(
      preferredLang,
      longTerm,
      sessionSummary,
      sessionContext,
      toolHint
    );

    // 把 toolResult 编码成 JSON 字符串
    const toolJson = JSON.stringify(toolResult);

    const messages: Message[] = [
      { role: "system", content: systemPrompt },
      { role: "user", content: originalUserText },
      { role: "user", content: `TOOL_RESULT_JSON:\n${toolJson}` }
    ];

    const content = await this.fetchFromProvider(messages);
    console.info("[AIService] Raw Response (after tool):", content);

    const jsonString = this.extractJsonData(content);
    const result = JSON.parse(jsonString) as MixedResult;

    // 二段也允许更新记忆
    if (result.newMemories && result.newMemories.length > 0) {
      const filtered = this.filterMemories(result.newMemories, result, content);
      for (const mem of filtered) {
        await memoryBank.saveMemory(mem, "Auto-Extracted");
      }
    }

    if (result.userProfile && result.userProfile.trim().length > 0) {
      await memoryBank.saveUserProfile(result.userProfile);
    }

    return result;
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
你是 Deadliner AI 数据分析专家。请根据用户上个月（${monthName}）的任务完成数据，生成一份简短的月度总结和一组关键词标签。

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

  // ==========================================
  // MARK: - Prompt builders (完全对齐 iOS + 强化防幻觉)
  // ==========================================

  private buildAgentSystemPrompt(
    preferredLang: string,
    longTermContext: string,
    sessionSummary: string,
    sessionContext: string,
    toolHint?: string
  ): string {
    const now = this.isoNowString();
    // ArkTS 获取时区偏移 (例如 UTC+8)
    const offset = -(new Date().getTimezoneOffset() / 60);
    const tz = `UTC${offset >= 0 ? '+' : ''}${offset}`;

    const summary = sessionSummary.substring(0, 600);
    const ctx = sessionContext.substring(0, 1200);
    const ltm = longTermContext.substring(0, 900);

    const toolHintStr = toolHint ? `【工具阶段提示】\n${toolHint}\n` : "";

    return `你是 Deadliner AI，一个“日程/习惯/闲聊”全能解析器（Agent Core）。

${toolHintStr}

【当前时间】${now}
【当前时区】${tz}
【用户语言】${preferredLang}

【长期记忆（画像+少量事实）】
${ltm}

【会话摘要（上一轮累计，<=600字符）】
${summary}

【短期对话窗口（最近内容，<=1200字符）】
${ctx}

要求：保持连续性。若与“短期窗口/会话摘要”冲突，优先以短期为准；若与“用户画像”冲突，优先以短期为准并可在 newMemories/userProfile 中修正。

必须输出纯 JSON（禁止 markdown/解释文字），字段规则如下：

你必须输出：
1) primaryIntent：只能是 "ExtractTasks" / "ExtractHabits" / "Chat"
2) tasks：当 primaryIntent="ExtractTasks" 时填充，否则可以省略或空数组
3) habits：当 primaryIntent="ExtractHabits" 时填充，否则可以省略或空数组
4) newMemories：必须且只能是一个纯字符串数组 (Array of Strings)。用于抽取新的稳定偏好/事实。绝对禁止输出嵌套对象(Object)或字典！如果没有要记住的内容，必须输出 []。
5) chatResponse：仅当 primaryIntent="Chat" 时给一句简短回复（否则可省略或空）。注意键名必须严格是 "chatResponse"，绝不能写成 "response"！
6) sessionSummary：必须输出。用 5-10 条要点总结“当前会话状态/未完成事项/确认流程”，总长度 <= 600 字符
7) userProfile：仅当你认为需要更新画像时输出（1段话，<= 420 字符）；否则可以省略或输出空字符串
8) toolCalls：当你需要读取用户真实任务列表才能回答时，输出 toolCalls（数组）。否则省略或输出空数组。

toolCalls 规则：
- tool 目前只能是 "readTasks"
- args 必须是：
    - timeRangeDays: Int（默认 7）
    - status: "OPEN" | "DONE" | "ALL"（默认 "OPEN"）
    - keywords: string[]（最多 3 个；每个最多 12 字；可为空）
    - limit: Int（默认 20，最大 50）
    - sort: "DUE_ASC" | "UPDATED_DESC"（默认 "DUE_ASC"）
- reason: 用 1 句话解释为什么要读任务（给用户授权卡展示）

【关键词强规则（必须遵守）】：
- toolCalls.args.keywords 只能来自“用户本轮输入 text”中明确出现的词或短语。
- 禁止从长期记忆、会话摘要、短期窗口中推断/补充 keywords。
- 若用户输入是泛查询（如“这周/最近/有哪些任务/列出任务”）且未指定主题词，则 keywords 必须是空数组或省略。

【二段工具回灌规则】：
- 如果你在用户消息中看到以 "TOOL_RESULT_JSON:" 开头的工具结果，表示任务数据已提供。
  你必须基于工具结果直接给出最终 JSON 输出。
- 你可以输出新的 tasks/habits proposal（用于新增、补全或纠错），但必须遵循：
  1) 除非用户明确要求“刷新/再查”，否则不要再次输出 toolCalls。
  2) 若工具结果中已存在高度相似的任务（同名或同义，且截止时间接近），不要重复输出同一任务；可以在 chatResponse 里提示“已存在，是否需要调整/合并”。
  3) 若用户的请求是“列出/查看/总结”，优先给 chatResponse；proposal 仅在确实需要用户确认新增/变更时输出。

【记忆抽取强规则】：
- newMemories 只能包含“长期稳定偏好/事实/约束”（例如：时间格式偏好、语言偏好、工作流偏好、长期项目背景）。
- 禁止把任何“待办/任务/提醒/本次要做的事”写入 newMemories（包括用户说的任务、你解析出的 tasks、你从 repo 读到的 tasks）。
- 如果用户输入是“提取任务/列出任务/这周有什么任务/添加任务”等任务相关请求，则 newMemories 必须为空数组或省略。

【时间推算强规则】：
- dueTime 必须严格是 "yyyy-MM-dd HH:mm" 或 ""。
- 若用户给了日期/相对日期但无具体时刻：必须补全默认时刻：
  - 早上/上午 -> 09:00
  - 中午 -> 12:00
  - 下午 -> 15:00
  - 晚上/夜里 -> 20:00
  - 只说“明天/下周/周三”等无时段词 -> 09:00
- 若用户明确说“不确定时间/到时候再说” -> dueTime = ""

【任务字段规则】：
- name：2-8字最佳，不超过15字；去冗词。
- note：细节补充；无则 ""。

【去重规则（强制）】：
- 若 readTasks 返回的 tasks 列表中存在 name 与新任务 name 相同或非常相似（编辑距离很近/同义），且 dueTime 相差 <= 6 小时：
  - 不要输出新的 tasks proposal
  - 在 chatResponse 中询问是否要“修改原任务的截止时间/备注”或“合并”

【习惯字段规则】：
- period：只能 "DAILY"/"WEEKLY"/"MONTHLY"，未提及默认 "DAILY"
- timesPerPeriod：整数，未提及默认 1
- goalType：只能 "PER_PERIOD"/"TOTAL"，默认 "PER_PERIOD"
- totalTarget：仅当 goalType="TOTAL" 时给整数

返回 JSON 示例（结构，不是固定值）：
{
  "primaryIntent": "ExtractTasks | ExtractHabits | Chat",
  "tasks": [{"name":"","dueTime":"yyyy-MM-dd HH:mm","note":""}],
  "habits": [{"name":"","period":"DAILY","timesPerPeriod":1,"goalType":"PER_PERIOD","totalTarget":300}],
  "newMemories": ["..."],
  "chatResponse": "...",
  "sessionSummary": "...",
  "userProfile": "...",
  "toolCalls": [{"tool":"readTasks","args":{"timeRangeDays":7,"status":"OPEN","keywords":["..."],"limit":20,"sort":"DUE_ASC"},"reason":"..."}]
}`;
  }

  private buildTaskSystemPrompt(preferredLang: string): string {
    const now = this.isoNowString();
    const offset = -(new Date().getTimezoneOffset() / 60);
    const tz = `UTC${offset >= 0 ? '+' : ''}${offset}`;

    return `你是 Deadliner AI 的任务提取器。
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

    return `你是 Deadliner AI 的习惯提取器。
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

  // ==========================================
  // MARK: - Memory Filtering
  // ==========================================

  private filterMemories(mems: string[], result: MixedResult, userText: string): string[] {
    const q = userText.toLowerCase();

    // 1) 任务/待办场景：直接不存记忆（最硬）
    const intent = (result.primaryIntent || "").toLowerCase();
    if (intent.includes("extracttasks") || intent.includes("extracthabits") || this.looksLikeTaskQuery(q)) {
      return [];
    }

    // 2) 如果 mem 与 tasks/habits 高度相关，也过滤
    // 【修复】：将 Set 替换为普通 Array，完美避开 ArkTS 遍历 Set 的迭代器 Bug
    const taskNames = (result.tasks || []).map(t => t.name.toLowerCase());
    const habitNames = (result.habits || []).map(h => h.name.toLowerCase());

    return mems
      .map(m => m.trim())
      .filter(m => m.length > 0)
      .filter(m => {
        const s = m.toLowerCase();

        // 2.1 过滤“像任务”的句子
        if (this.looksLikeTaskMemory(s)) return false;

        // 2.2 过滤与任务名/习惯名重合的 (改用 includes)
        if (taskNames.includes(s) || habitNames.includes(s)) return false;

        // 2.3 过滤包含任何任务名的
        for (const taskName of taskNames) {
          if (taskName && s.includes(taskName)) return false;
        }

        return true;
      });
  }

  private looksLikeTaskQuery(q: string): boolean {
    const patterns = ["有什么任务", "有哪些任务", "任务列表", "这周", "本周", "明天", "今天", "待办", "deadline", "ddl", "to do", "todo", "提醒我"];
    return patterns.some(p => q.includes(p));
  }

  private looksLikeTaskMemory(s: string): boolean {
    const timeHints = ["-", ":", "点", "号", "周", "明天", "今天", "截止", "due", "deadline"];
    const actionHints = ["交", "提交", "完成", "做", "开会", "复习", "写", "买", "打电话", "发送"];

    const hasTime = timeHints.some(h => s.includes(h));
    const hasAction = actionHints.some(h => s.includes(h));

    return hasTime && hasAction;
  }
}
