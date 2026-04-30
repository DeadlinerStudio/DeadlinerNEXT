import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeadlinerCore, extractTasksJson } from 'libffi_ohos.so';
import { AIHabit, AITask, AIToolCall, AIToolResult, MixedResult } from '../model/AIModels';
import { LocalValues } from '../../common/local/LocalValues';
import { MemoryBank, MemoryFragment } from '../model/MemoryModels';
import {
  AdapterCreateHabitPayload,
  AdapterCreateTaskPayload,
  AdapterErrorPayload,
  AdapterReadHabitsPayload,
  AdapterReadTasksPayload,
  DeadlinerToolAdapter
} from './DeadlinerToolAdapter';

interface CoreLifecycleEvent {
  type: string;
  requestId?: string;
  stage?: string;
  status?: string;
  message?: string | null;
}

interface CoreToolRequestMeta {
  executionMode?: string;
}

interface CoreMetaWrapper {
  _meta?: CoreToolRequestMeta;
}

interface CoreToolRequestArgsEnvelope {
  meta?: CoreToolRequestMeta | null;
}

interface CoreToolRequestEvent {
  type: string;
  id: string;
  toolName: string;
  argsJson: string;
  argsObject?: Object | null;
  argsEnvelope?: CoreToolRequestArgsEnvelope | null;
}

interface CoreFinishEvent {
  type: string;
  primaryIntent?: string | null;
  tasks?: AITask[] | null;
  habits?: AIHabit[] | null;
  chatResponse?: string | null;
  sessionSummary?: string | null;
}

interface CoreThinkingEvent {
  type: string;
  agentName?: string | null;
  phase?: string | null;
  message?: string | null;
}

interface CoreErrorEvent {
  type: string;
  message: string;
}

interface CoreMemoryCommittedEvent {
  type: string;
  addedMemories?: string[] | null;
  profileUpdated?: boolean;
  newRevision?: number;
}

interface CoreSnapshotFragment {
  id: string;
  content: string;
  category: string;
  timestamp: string;
  importance: number;
}

interface CoreMemorySnapshot {
  revision?: number;
  fragments?: CoreSnapshotFragment[] | null;
  userProfile?: string;
}

class EmptyObject {
}

class EmptyMixedResult implements MixedResult {
  primaryIntent?: string;
  tasks?: AITask[];
  habits?: AIHabit[];
  newMemories?: string[];
  chatResponse?: string;
  sessionSummary?: string;
  userProfile?: string;
  toolCalls?: AIToolCall[];
}

export interface CoreProgressUpdate {
  kind: string;
  message: string;
}

export class DeadlinerCoreService {
  private static instance: DeadlinerCoreService;
  private static readonly LOG_DOMAIN: number = 0xD311;
  private static readonly LOG_TAG: string = 'LifiCore';

  private context: common.Context | null = null;
  private core: DeadlinerCore | null = null;
  private configSignature: string = '';
  private progressHandler?: (update: CoreProgressUpdate) => void;
  private uiSessionId: number = 0;

  public static getInstance(): DeadlinerCoreService {
    if (!DeadlinerCoreService.instance) {
      DeadlinerCoreService.instance = new DeadlinerCoreService();
    }
    return DeadlinerCoreService.instance;
  }

  public async init(context: common.Context): Promise<void> {
    this.context = context;
    await MemoryBank.getInstance().init(context);
    this.logInfo(`MemoryBank initialized. fragments=${MemoryBank.getInstance().fragments.length} profile=${MemoryBank.getInstance().userProfile.length > 0}`);
  }

  public setProgressHandler(handler?: (update: CoreProgressUpdate) => void): void {
    this.progressHandler = handler;
  }

  public startUiSession(): void {
    this.uiSessionId += 1;
    this.core = null;
    this.configSignature = '';
    this.logInfo(`startUiSession session=${this.uiSessionId}`);
  }

  public async processInput(text: string): Promise<MixedResult> {
    await this.ensureCore();
    this.discardPendingEvents('before processInput');
    await this.pushMemorySnapshotToCore();
    const core = this.requireCore();
    this.logInfo(`processInput start text=${text}`);
    await core.processInput(text);
    const result = await this.collectResult();
    await this.awaitMemorySettle(result, 'processInput');
    await this.pullMemorySnapshotFromCore();
    this.logInfo(`processInput finish toolCalls=${result.toolCalls?.length ?? 0} tasks=${result.tasks?.length ?? 0} habits=${result.habits?.length ?? 0} memories=${result.newMemories?.length ?? 0}`);
    return result;
  }

  public async submitToolResult(toolResult: AIToolResult): Promise<MixedResult> {
    await this.ensureCore();
    const core = this.requireCore();
    this.discardPendingEvents('before submitToolResult');
    this.logInfo(`submitToolResult start tool=${toolResult.tool} id=${toolResult.id} result=${toolResult.resultJson}`);
    await core.submitToolResult(toolResult.id, toolResult.resultJson);
    const result = await this.collectResult();
    await this.awaitMemorySettle(result, 'submitToolResult');
    await this.pullMemorySnapshotFromCore();
    this.logInfo(`submitToolResult finish tool=${toolResult.tool} chat=${result.chatResponse ? 'yes' : 'no'} memories=${result.newMemories?.length ?? 0}`);
    return result;
  }

  public async runToolCall(call: AIToolCall): Promise<AIToolResult> {
    const argsObject: Object = call.args ?? new EmptyObject();
    this.logInfo(`runToolCall tool=${call.tool} id=${call.id ?? ''} args=${JSON.stringify(argsObject)}`);
    const execution = await DeadlinerToolAdapter.getInstance().execute({
      id: call.id ?? '',
      toolName: call.tool,
      argsJson: JSON.stringify(argsObject)
    });

    const result: AIToolResult = {
      id: call.id ?? '',
      tool: call.tool,
      appliedArgs: argsObject,
      payload: execution.payload,
      resultJson: execution.resultJson,
      generatedAt: new Date()
    };
    this.logInfo(`runToolCall done tool=${call.tool} result=${execution.resultJson}`);
    return result;
  }

  public extractTasks(text: string, preferredLang: string): AITask[] {
    const payloadText: string = extractTasksJson(text, preferredLang);
    const payload: AITask[] = JSON.parse(payloadText) as AITask[];
    return payload;
  }

  private async ensureCore(): Promise<void> {
    if (!this.context) {
      throw new Error('DeadlinerCore 尚未初始化上下文');
    }

    const local = LocalValues.getInstance();
    const apiKey = local.getDeepSeekApiKey();
    const baseUrl = local.getAIBaseUrl();
    const modelId = local.getAIModel() || 'deepseek-chat';

    if (!apiKey) {
      throw new Error('请先在设置中填写 API Key');
    }

    const nextSignature = `${apiKey}::${baseUrl}::${modelId}`;
    if (this.core && this.configSignature === nextSignature) {
      return;
    }

    const storagePath = `${this.context.filesDir}/deadliner_ai_core`;
    this.core = new DeadlinerCore(apiKey, baseUrl, modelId, storagePath, 'harmony');
    this.configSignature = nextSignature;
  }

  private requireCore(): DeadlinerCore {
    if (!this.core) {
      throw new Error('DeadlinerCore 尚未创建');
    }
    return this.core;
  }

  private async collectResult(): Promise<EmptyMixedResult> {
    const result: EmptyMixedResult = new EmptyMixedResult();
    let sawToolRequest = false;
    let sawOrchestrationCompleted = false;
    let sawMemoryCommitSignal = false;
    let idleRoundsAfterFinish = 0;

    for (let round = 0; round < 240; round++) {
      const events = this.drainEventObjects();
      if (events.length > 0) {
        idleRoundsAfterFinish = 0;
        for (const event of events) {
          const eventType = this.readEventType(event);
          if (eventType === 'toolRequest') {
            const toolEvent = event as CoreToolRequestEvent;
            const parsedCall = this.buildToolCall(toolEvent);
            this.logInfo(`event toolRequest tool=${parsedCall.tool} id=${parsedCall.id ?? ''}`);
            this.emitProgress('thinking', this.toolCollaborationMessage(parsedCall.tool));
            result.toolCalls = [parsedCall];
            sawToolRequest = true;
          } else if (eventType === 'thinking') {
            const thinkingEvent = event as CoreThinkingEvent;
            this.logInfo(`event thinking phase=${thinkingEvent.phase ?? ''} agent=${thinkingEvent.agentName ?? ''} message=${thinkingEvent.message ?? ''}`);
            this.emitProgress('thinking', this.thinkingMessage(thinkingEvent));
          } else if (eventType === 'finish') {
            const finishEvent = event as CoreFinishEvent;
            result.primaryIntent = finishEvent.primaryIntent ?? undefined;
            result.tasks = finishEvent.tasks ?? undefined;
            result.habits = finishEvent.habits ?? undefined;
            result.chatResponse = finishEvent.chatResponse ?? undefined;
            result.sessionSummary = finishEvent.sessionSummary ?? undefined;
            this.logInfo(`event finish intent=${finishEvent.primaryIntent ?? ''} tasks=${finishEvent.tasks?.length ?? 0} habits=${finishEvent.habits?.length ?? 0}`);
          } else if (eventType === 'memoryCommitted') {
            const memoryEvent = event as CoreMemoryCommittedEvent;
            result.newMemories = memoryEvent.addedMemories ?? undefined;
            if (memoryEvent.profileUpdated) {
              result.userProfile = this.requireCore().getUserProfile();
            }
            this.emitProgress('memory', this.memoryCommittedMessage(memoryEvent));
            this.logInfo(`event memoryCommitted added=${memoryEvent.addedMemories?.length ?? 0} profileUpdated=${memoryEvent.profileUpdated ? 'true' : 'false'} revision=${memoryEvent.newRevision ?? -1}`);
            sawMemoryCommitSignal = true;
          } else if (eventType === 'error') {
            const errorEvent = event as CoreErrorEvent;
            this.logError(`event error message=${errorEvent.message}`);
            throw new Error(errorEvent.message || 'DeadlinerCore 执行失败');
          } else if (eventType === 'lifecycle') {
            const lifecycle = event as CoreLifecycleEvent;
            this.logInfo(`event lifecycle stage=${lifecycle.stage ?? ''} status=${lifecycle.status ?? ''} message=${lifecycle.message ?? ''}`);
            this.emitProgress('lifecycle', this.lifecycleMessage(lifecycle));
            if ((lifecycle.status ?? '').endsWith('failed')) {
              this.logError(`lifecycle failed stage=${lifecycle.stage ?? ''} status=${lifecycle.status ?? ''} message=${lifecycle.message ?? ''}`);
              throw new Error(lifecycle.message ?? `${lifecycle.stage}.${lifecycle.status}`);
            }
            if (
              lifecycle.stage === 'tool_request' && lifecycle.status === 'waiting'
            ) {
              sawToolRequest = true;
            }
            if (lifecycle.stage === 'orchestration' && lifecycle.status === 'completed') {
              sawOrchestrationCompleted = true;
            }
            if (lifecycle.stage === 'memory_commit' && lifecycle.status === 'completed') {
              sawMemoryCommitSignal = true;
            }
          }
        }
      } else if (sawOrchestrationCompleted) {
        idleRoundsAfterFinish += 1;
      }

      const pendingCount = this.requireCore().pendingEventCount();
      if (sawToolRequest && pendingCount === 0) {
        break;
      }
      if (sawOrchestrationCompleted && sawMemoryCommitSignal && pendingCount === 0) {
        break;
      }
      if (sawOrchestrationCompleted && pendingCount === 0 && idleRoundsAfterFinish >= 30) {
        this.logInfo('memory commit grace window elapsed without additional events');
        break;
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 20));
    }

    return result;
  }

  private async awaitMemorySettle(result: EmptyMixedResult, source: string): Promise<void> {
    if (result.toolCalls && result.toolCalls.length > 0) {
      return;
    }

    const core = this.requireCore();
    for (let round = 0; round < 150; round++) {
      const syncJson = core.getLastMemorySyncJson();
      if (syncJson && syncJson.length > 0) {
        this.logInfo(`${source} observed getLastMemorySyncJson at round=${round}`);
        return;
      }

      const events = this.drainEventObjects();
      if (events.length > 0) {
        for (const event of events) {
          this.applyPostFinishEvent(result, event);
        }
      }

      if (result.newMemories && result.newMemories.length > 0) {
        this.logInfo(`${source} observed memoryCommitted event at round=${round}`);
        return;
      }

      await new Promise<void>((resolve) => setTimeout(resolve, 20));
    }

    this.logInfo(`${source} memory settle timeout`);
  }

  private drainEventObjects(): Object[] {
    const core = this.requireCore();
    const serialized: string = core.drainEventsJson();
    if (!serialized || serialized === '[]') {
      return [];
    }

    const rawItems: string[] = JSON.parse(serialized) as string[];
    const events: Object[] = [];
    for (const rawItem of rawItems) {
      events.push(JSON.parse(rawItem) as Object);
    }
    return events;
  }

  private readEventType(event: Object): string {
    const lifecycle = event as CoreLifecycleEvent;
    if (lifecycle.type) {
      return lifecycle.type;
    }
    return '';
  }

  private applyPostFinishEvent(result: EmptyMixedResult, event: Object): void {
    const eventType = this.readEventType(event);
    if (eventType === 'memoryCommitted') {
      const memoryEvent = event as CoreMemoryCommittedEvent;
      result.newMemories = memoryEvent.addedMemories ?? undefined;
      if (memoryEvent.profileUpdated) {
        result.userProfile = this.requireCore().getUserProfile();
      }
      this.emitProgress('memory', this.memoryCommittedMessage(memoryEvent));
      this.logInfo(`post-finish memoryCommitted added=${memoryEvent.addedMemories?.length ?? 0} profileUpdated=${memoryEvent.profileUpdated ? 'true' : 'false'} revision=${memoryEvent.newRevision ?? -1}`);
      return;
    }

    if (eventType === 'lifecycle') {
      const lifecycle = event as CoreLifecycleEvent;
      this.logInfo(`post-finish lifecycle stage=${lifecycle.stage ?? ''} status=${lifecycle.status ?? ''} message=${lifecycle.message ?? ''}`);
      this.emitProgress('lifecycle', this.lifecycleMessage(lifecycle));
      return;
    }

    if (eventType === 'thinking') {
      const thinkingEvent = event as CoreThinkingEvent;
      this.logInfo(`post-finish thinking phase=${thinkingEvent.phase ?? ''} agent=${thinkingEvent.agentName ?? ''} message=${thinkingEvent.message ?? ''}`);
      this.emitProgress('thinking', this.thinkingMessage(thinkingEvent));
      return;
    }

    if (eventType === 'error') {
      const errorEvent = event as CoreErrorEvent;
      this.logError(`post-finish error message=${errorEvent.message}`);
    }
  }

  private buildToolCall(toolEvent: CoreToolRequestEvent): AIToolCall {
    const argsObject = this.parseToolArgsObject(toolEvent.argsJson);
    const executionMode = this.parseExecutionMode(toolEvent.argsJson);
    const toolCall: AIToolCall = {
      id: toolEvent.id,
      tool: toolEvent.toolName,
      args: argsObject,
      executionMode: executionMode
    };
    return toolCall;
  }

  private parseToolArgsObject(argsJson: string): Object {
    const parsed: Object = JSON.parse(argsJson) as Object;
    return parsed;
  }

  private parseExecutionMode(argsJson: string): string | undefined {
    const parsed = JSON.parse(argsJson) as CoreMetaWrapper;
    return parsed._meta?.executionMode;
  }

  private discardPendingEvents(reason: string): void {
    if (!this.core) {
      return;
    }
    const pendingCount = this.core.pendingEventCount();
    if (pendingCount <= 0) {
      return;
    }
    const discarded = this.drainEventObjects();
    this.logInfo(`discardPendingEvents reason=${reason} pending=${pendingCount} discarded=${discarded.length}`);
  }

  private emitProgress(kind: string, message: string): void {
    if (!message || !this.progressHandler) {
      return;
    }
    this.progressHandler({
      kind: kind,
      message: message
    });
  }

  private lifecycleMessage(event: CoreLifecycleEvent): string {
    const stage = event.stage ?? '';
    const status = event.status ?? '';

    if (stage === 'process_input' && status === 'started') {
      return 'Deadliner 正在理解你的输入...';
    }
    if (stage === 'tool_request' && status === 'waiting') {
      return 'Deadliner 正在等待本地操作结果...';
    }
    if (stage === 'submit_tool_result' && status === 'started') {
      return 'Deadliner 正在吸收工具结果...';
    }
    if (stage === 'orchestration' && status === 'completed') {
      return 'Deadliner 已完成本轮编排。';
    }
    if (stage === 'memory_commit' && status === 'completed') {
      return 'Deadliner 正在同步记忆...';
    }
    if (event.message && event.message.length > 0) {
      return event.message;
    }
    return '';
  }

  private thinkingMessage(event: CoreThinkingEvent): string {
    const phase = event.phase ?? '';
    const agentName = event.agentName ?? '';

    if (event.message && event.message.length > 0) {
      return event.message;
    }
    if (phase === 'memory') {
      return 'Deadliner 正在检查记忆上下文...';
    }
    if (agentName.toLowerCase().includes('task')) {
      return 'Deadliner 正在整理任务方案...';
    }
    if (agentName.toLowerCase().includes('habit')) {
      return 'Deadliner 正在整理习惯方案...';
    }
    if (agentName.toLowerCase().includes('chat')) {
      return 'Deadliner 正在组织回复...';
    }
    return 'Deadliner 正在协作处理中...';
  }

  private toolCollaborationMessage(toolName: string): string {
    switch (toolName) {
      case 'read_tasks':
        return 'Deadliner 想先看看你现在的任务。';
      case 'create_task':
        return 'Deadliner 已经整理好一个待创建任务。';
      case 'update_deadline':
        return 'Deadliner 已经整理好一个待修改截止时间的任务。';
      case 'read_habits':
        return 'Deadliner 想先看看你现在的习惯。';
      case 'create_habit':
        return 'Deadliner 已经整理好一个待创建习惯。';
      default:
        return 'Deadliner 正在请求本地协作。';
    }
  }

  private memoryCommittedMessage(event: CoreMemoryCommittedEvent): string {
    const memoryCount = event.addedMemories?.length ?? 0;
    if (memoryCount > 0) {
      return `Deadliner 已记住 ${memoryCount} 条新信息。`;
    }
    if (event.profileUpdated) {
      return 'Deadliner 已更新用户画像。';
    }
    return 'Deadliner 已完成记忆同步。';
  }

  private async pushMemorySnapshotToCore(): Promise<void> {
    const core = this.requireCore();
    const bank = MemoryBank.getInstance();
    const fragments: CoreSnapshotFragment[] = [];

    for (const fragment of bank.fragments) {
      const snapshotFragment: CoreSnapshotFragment = {
        id: fragment.id,
        content: fragment.content,
        category: fragment.category,
        timestamp: new Date(fragment.timestamp).toISOString(),
        importance: fragment.importance
      };
      fragments.push(snapshotFragment);
    }

    const snapshot: CoreMemorySnapshot = {
      revision: 0,
      fragments: fragments,
      userProfile: bank.userProfile
    };
    this.logInfo(`pushMemorySnapshot fragments=${fragments.length} profile=${bank.userProfile.length > 0}`);
    await core.replaceMemorySnapshot(JSON.stringify(snapshot));
  }

  private async pullMemorySnapshotFromCore(): Promise<void> {
    const core = this.requireCore();
    const rawText: string = core.exportMemorySnapshot();
    if (!rawText) {
      this.logInfo('pullMemorySnapshot skipped empty snapshot');
      return;
    }

    const snapshot: CoreMemorySnapshot = JSON.parse(rawText) as CoreMemorySnapshot;
    const bank = MemoryBank.getInstance();
    const fragments: MemoryFragment[] = [];

    for (const fragment of snapshot.fragments ?? []) {
      const memoryFragment: MemoryFragment = {
        id: fragment.id,
        content: fragment.content,
        category: fragment.category,
        timestamp: new Date(fragment.timestamp).getTime(),
        importance: fragment.importance
      };
      fragments.push(memoryFragment);
    }

    await bank.replaceAllFragments(fragments);
    await bank.setUserProfileAllowEmpty(snapshot.userProfile ?? '');
    this.logInfo(`pullMemorySnapshot applied fragments=${fragments.length} profile=${(snapshot.userProfile ?? '').length > 0}`);
  }

  private logInfo(message: string): void {
    hilog.info(DeadlinerCoreService.LOG_DOMAIN, DeadlinerCoreService.LOG_TAG, '%{public}s', message);
    console.info(`[LifiCore] ${message}`);
  }

  private logError(message: string): void {
    hilog.error(DeadlinerCoreService.LOG_DOMAIN, DeadlinerCoreService.LOG_TAG, '%{public}s', message);
    console.error(`[LifiCore] ${message}`);
  }
}
