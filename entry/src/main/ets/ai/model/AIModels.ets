// ==========================================
// 1. API 请求/响应模型 (DeepSeek/OpenAI 兼容)
// 结合了 ArkTS 的详细定义 (Usage 等)
// ==========================================

export interface Message {
  role: string;
  content: string;
}

export interface ChatRequest {
  model: string;
  messages: Message[];
  stream?: boolean;
  temperature?: number;
}

export interface ChatResponse {
  choices: Choice[];
  usage?: Usage;
}

export interface Choice {
  message: Message;
  finish_reason?: string;
}

export interface Usage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
}

// ==========================================
// 2. AI 核心业务实体模型 (Data Transfer Objects)
// 结合了 ArkTS 的详细类型和 iOS 的字段
// ==========================================

export enum IntentType {
  ExtractTasks = 'ExtractTasks',
  PlanDay = 'PlanDay',
  SplitToSteps = 'SplitToSteps',
  // 预留更多意图，如 Chat, Search 等
}

export interface AITask {
  name: string;
  dueTime?: string; // "yyyy-MM-dd HH:mm"
  note?: string;
}

export interface AIHabit {
  name: string;
  period: 'DAILY' | 'WEEKLY' | 'MONTHLY' | string;
  timesPerPeriod: number;
  goalType: 'PER_PERIOD' | 'TOTAL' | string;
  totalTarget?: number;
}

export interface PlanBlock {
  title: string;
  start: string; // "yyyy-MM-dd HH:mm"
  end: string;
  location?: string;
  energy?: string; // low/med/high
  linkTask?: string;
}

export interface SplitStepsResult {
  title: string;
  checklist: string[];
}

// ==========================================
// 3. 混合解析结果 (大一统 MixedResult)
// 合并了 iOS 的会话/记忆/工具 + ArkTS 的计划/拆解
// ==========================================

export interface MixedResult {
  primaryIntent?: IntentType | string;
  tasks?: AITask[];
  habits?: AIHabit[];
  planBlocks?: PlanBlock[];         // From ArkTS
  steps?: SplitStepsResult[];       // From ArkTS
  newMemories?: string[];           // From iOS: 记忆提取
  chatResponse?: string;            // From iOS: AI 的暖心回复
  sessionSummary?: string;          // From iOS: 会话摘要（短期）
  userProfile?: string;             // From iOS: 长期画像（可选更新）
  toolCalls?: AIToolCall[];         // From iOS: 工具调用
}

// ==========================================
// 4. Tool Calls (MCP-like 机制)
// 从 iOS 完整迁移到 ArkTS
// ==========================================

export interface AIToolCall {
  tool: string;
  args: ReadTasksArgs;
  reason?: string;
}

export interface ReadTasksArgs {
  timeRangeDays?: number; // default 7
  status?: string;        // "OPEN" | "DONE" | "ALL"
  keywords?: string[];    // <=3
  limit?: number;         // default 20, max 50
  sort?: string;          // "DUE_ASC" | "UPDATED_DESC"
}

// App 端处理 Tool 请求/结果的包装类
// 注意：ArkTS 中用 string 替代 Swift 的 UUID
export interface AIToolRequest {
  id: string; // uuid
  tool: string; // "readTasks"
  args: ReadTasksArgs;
  reason?: string;
}

export interface AIToolResult {
  id: string; // uuid
  tool: string; // "readTasks"
  appliedArgs: ReadTasksArgs;
  payload: ReadTasksResultPayload;
  generatedAt: Date;
}

// 供 AI 阅读的精简上下文 DTO
export interface ReadTasksResultPayload {
  tasks: TaskDigestItem[];
  summary: TaskSummary;
}

export interface TaskDigestItem {
  id: number; // TS/ArkTS 没有 Int64，用 number 表示
  name: string;
  due: string; // "yyyy-MM-dd HH:mm" or ""
  status: string; // "OPEN" | "DONE"
  notePreview: string; // <= 40 chars
}

export interface TaskSummary {
  count: number;
  overdue: number;
  dueSoon24h: number;
}

export interface MonthlyAnalysisResult {
  month: string;
  summary: string;
  keywords: string[];
  generatedAt?: string;
}

// ==========================================
// 5. 错误定义及其他工具模型
// ==========================================

// iOS 错误枚举翻译为 ArkTS 可用的枚举格式
export enum AIErrorType {
  MISSING_API_KEY = "MISSING_API_KEY",
  EMPTY_RESPONSE = "EMPTY_RESPONSE",
  PARSING_FAILED = "PARSING_FAILED",
  NETWORK_ERROR = "NETWORK_ERROR"
}

export class AIError extends Error {
  public type: AIErrorType;
  public originalError?: Error;

  constructor(type: AIErrorType, message?: string, originalError?: Error) {
    super(message || AIError.getDefaultMessage(type));
    this.name = "AIError";
    this.type = type;
    this.originalError = originalError;
  }

  static getDefaultMessage(type: AIErrorType): string {
    switch (type) {
      case AIErrorType.MISSING_API_KEY: return "请先在设置中填写 DeepSeek API Key";
      case AIErrorType.EMPTY_RESPONSE: return "AI 返回内容为空";
      case AIErrorType.PARSING_FAILED: return "AI 数据解析失败";
      case AIErrorType.NETWORK_ERROR: return "网络请求失败";
      default: return "未知 AI 错误";
    }
  }
}

// From ArkTS: Check API Response
export interface DeadlinerCheckResp {
  valid: boolean;
  message?: string;
  remainingQuota?: number;
}
