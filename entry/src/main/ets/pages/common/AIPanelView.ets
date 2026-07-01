import { i18n } from '@kit.LocalizationKit';
import util from '@ohos.util';
import {
  AITask,
  AIHabit,
  AIToolRequest,
  AIToolResult,
  ReadTasksArgs,
  MixedResult
} from '../../ai/model/AIModels';
import {
  defaultToolReason,
  habitProposalsFromToolRequest,
  makeHabitKey,
  makeTaskKey,
  sanitizeReadTasksArgs,
  taskProposalsFromToolRequest,
  toolArgsDetail,
  toolArgsSummary,
  toolDisplayTitle,
  toolResultSummary
} from './ai/AIPanelToolUtils';
import { ITheme } from '../../common/theme/ThemeModel';
import { LoginPanelView } from './LoginPanelView';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { DateTimeUtils } from '../../utils/DateTimeUtils';
import { DeadlineType } from '../../model/DDLModels';
import { MemoryBank } from '../../ai/model/MemoryModels';
import { AIService } from '../../ai/AIServcice';
import { DeadlinerCoreService } from '../../ai/core/DeadlinerCoreService';
import {
  AdapterCreateHabitPayload,
  AdapterCreateTaskPayload
} from '../../ai/core/DeadlinerToolAdapter';
import {
  AIConversationHistoryRecord,
  AIWorkspaceSessionSnapshot,
  DisplayItem,
  DisplayItemType,
  ProposalToolRequestLink,
  restoreDisplayItems,
  snapshotDisplayItem
} from './ai/AIPanelModels';
import { MemoryManageSheet } from './MemoryManageSheet';
import { HabitFormHelper } from '../routes/main/modify/habit/HabitFormHelper';
import { Symbol } from '../components/infra/Symbol';

// ==========================================
// MARK: - 核心 UI 组件
// ==========================================

@Component
export struct AIWorkspaceView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp(C.KEY_DIRECT_ADD_ON_AI) directAdd: boolean = true;
  @StorageProp(C.KEY_AI_SILENT_TASK_ADD) silentTaskAdd: boolean = true;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @Prop bypassHuaweiLogin: boolean = false;
  @Prop topAvoidHeight: number = 0;
  @Prop @Watch('onStartNewChatSignal') startNewChatSignal: number = 0;
  @Prop externalSessionSnapshot: AIWorkspaceSessionSnapshot | null = null;
  @Prop @Watch('onExternalSessionVersionChange') externalSessionVersion: number = 0;
  @Prop readonlyHistoryRecord: AIConversationHistoryRecord | null = null;
  @Prop @Watch('onReadonlyHistoryVersionChange') readonlyHistoryVersion: number = 0;
  @Require onSessionSnapshotChange: (snapshot: AIWorkspaceSessionSnapshot) => void;

  // --- 状态控制 ---
  @State inputText: string = '';
  @State isParsing: boolean = false;
  @State displayItems: DisplayItem[] = [];

  @State sessionSummary: string = '';
  @State addedTaskKeys: string[] = [];  // 替代 Swift 的 Set
  @State addedHabitKeys: string[] = []; // 替代 Swift 的 Set
  @State repoBusy: boolean = false;

  // UI 刷新辅助状态
  @State memoryProfileCount: number = 0;
  @State currentProgressHint: string = '';
  @State lastSubmittedToolName: string = '';
  @State taskProposalToolRequests: ProposalToolRequestLink[] = [];
  @State habitProposalToolRequests: ProposalToolRequestLink[] = [];

  private scroller: Scroller = new Scroller();
  private toolOriginalUserText: string = "";
  private coreService: DeadlinerCoreService = DeadlinerCoreService.getInstance();

  @State showMemorySheet: boolean = false;

  @State hasUserProfile: boolean = false;
  @State memoryFragmentCount: number = 0;
  @State isReadonlyHistoryMode: boolean = false;

  @Prop bottomPadding: number = 0;

  aboutToAppear() {
    // 初始化记忆银行并触发 UI 更新
    MemoryBank.getInstance().init(getContext(this)).then(() => {
      this.refreshMemoryState();
    });
    this.coreService.startUiSession();
    this.coreService.setProgressHandler((update) => {
      this.handleProgressUpdate(update.kind, update.message);
    });
    if (this.readonlyHistoryRecord) {
      this.restoreReadonlyHistory(this.readonlyHistoryRecord);
    } else if (this.externalSessionSnapshot) {
      this.restoreWorkspaceSession(this.externalSessionSnapshot);
    }
  }

  aboutToDisappear() {
    if (!this.isReadonlyHistoryMode) {
      this.emitSessionSnapshotChange();
    }
    this.coreService.setProgressHandler(undefined);
  }

  onStartNewChatSignal(): void {
    if (this.startNewChatSignal <= 0) {
      return;
    }
    this.resetWorkspaceSession();
  }

  onExternalSessionVersionChange(): void {
    if (!this.externalSessionSnapshot) {
      return;
    }
    this.restoreWorkspaceSession(this.externalSessionSnapshot);
  }

  onReadonlyHistoryVersionChange(): void {
    if (!this.readonlyHistoryRecord) {
      return;
    }
    this.restoreReadonlyHistory(this.readonlyHistoryRecord);
  }

  private refreshMemoryState() {
    const mb = MemoryBank.getInstance();
    this.hasUserProfile = mb.userProfile.trim().length > 0;
    this.memoryFragmentCount = mb.fragments.length;
    this.memoryProfileCount = mb.fragments.length + (this.hasUserProfile ? 1 : 0);
  }

  private resetWorkspaceSession(): void {
    this.inputText = '';
    this.isParsing = false;
    this.displayItems = [];
    this.sessionSummary = '';
    this.addedTaskKeys = [];
    this.addedHabitKeys = [];
    this.repoBusy = false;
    this.currentProgressHint = '';
    this.lastSubmittedToolName = '';
    this.taskProposalToolRequests = [];
    this.habitProposalToolRequests = [];
    this.toolOriginalUserText = '';
    this.showMemorySheet = false;
    this.isReadonlyHistoryMode = false;
    this.coreService.startUiSession();
    this.refreshMemoryState();
    this.scrollToBottom();
    this.emitSessionSnapshotChange();
  }

  private restoreWorkspaceSession(snapshot: AIWorkspaceSessionSnapshot): void {
    this.inputText = '';
    this.isParsing = false;
    this.repoBusy = false;
    this.currentProgressHint = '';
    this.showMemorySheet = false;
    this.isReadonlyHistoryMode = false;
    this.displayItems = restoreDisplayItems(snapshot.displayItems);
    this.sessionSummary = snapshot.sessionSummary;
    this.addedTaskKeys = [...snapshot.addedTaskKeys];
    this.addedHabitKeys = [...snapshot.addedHabitKeys];
    this.taskProposalToolRequests = [...snapshot.taskProposalToolRequests];
    this.habitProposalToolRequests = [...snapshot.habitProposalToolRequests];
    this.lastSubmittedToolName = snapshot.lastSubmittedToolName;
    this.toolOriginalUserText = snapshot.toolOriginalUserText;
    this.coreService.startUiSession();
    this.scrollToBottom();
  }

  private restoreReadonlyHistory(record: AIConversationHistoryRecord): void {
    this.inputText = '';
    this.isParsing = false;
    this.repoBusy = false;
    this.currentProgressHint = '';
    this.showMemorySheet = false;
    this.isReadonlyHistoryMode = true;
    this.displayItems = restoreDisplayItems(record.displayItems);
    this.sessionSummary = '';
    this.addedTaskKeys = [];
    this.addedHabitKeys = [];
    this.taskProposalToolRequests = [];
    this.habitProposalToolRequests = [];
    this.lastSubmittedToolName = '';
    this.toolOriginalUserText = '';
    this.scrollToBottom();
  }

  private buildSessionSnapshot(): AIWorkspaceSessionSnapshot {
    return {
      displayItems: this.displayItems.map((item) => snapshotDisplayItem(item)),
      sessionSummary: this.sessionSummary,
      addedTaskKeys: [...this.addedTaskKeys],
      addedHabitKeys: [...this.addedHabitKeys],
      taskProposalToolRequests: [...this.taskProposalToolRequests],
      habitProposalToolRequests: [...this.habitProposalToolRequests],
      lastSubmittedToolName: this.lastSubmittedToolName,
      toolOriginalUserText: this.toolOriginalUserText,
      updatedAt: Date.now()
    };
  }

  private emitSessionSnapshotChange(): void {
    if (this.isReadonlyHistoryMode) {
      return;
    }
    this.onSessionSnapshotChange(this.buildSessionSnapshot());
  }

  // ==========================================
  // MARK: - 业务逻辑 (Agent Core)
  // ==========================================

  async runSmartAgent(textToRun?: string) {
    const query = (textToRun || this.inputText).trim();
    if (!query || this.isParsing || this.isReadonlyHistoryMode) return;

    // 1. 上屏用户消息
    const userItem = new DisplayItem(DisplayItemType.UserQuery);
    userItem.text = query;
    this.displayItems.push(userItem);
    this.inputText = '';
    this.isParsing = true;
    this.scrollToBottom();
    this.emitSessionSnapshotChange();

    try {
      const sysLang = i18n.System.getSystemLanguage();
      const sessionCtx = this.buildSessionContextString();

      const result = await AIService.getInstance().processInput(
        query, sysLang, sessionCtx, this.sessionSummary
      );

      if (result.sessionSummary) {
        this.sessionSummary = result.sessionSummary.substring(0, 600);
      }

      // 2. 拦截 Tool Call
      if (await this.handleToolCalls(result, query)) {
        this.isParsing = false;
        this.scrollToBottom();
        return;
      }

      // 3. 常规结果上屏
      this.appendResultToUI(result);

    } catch (err) {
      console.error("[AIPanelView] Error:", JSON.stringify(err));
      const errItem = new DisplayItem(DisplayItemType.AIChat);
      errItem.text = `抱歉，遇到问题：${err instanceof Error ? err.message : '未知网络错误'}`;
      this.displayItems.push(errItem);
    } finally {
      this.isParsing = false;
      this.refreshMemoryState();
      this.scrollToBottom();
      this.emitSessionSnapshotChange();
    }
  }

  // ==========================================
  // MARK: - Tool 审批与回灌逻辑
  // ==========================================

  async approveAndRunTool(req: AIToolRequest) {
    if (this.repoBusy) return;
    this.repoBusy = true;
    this.isParsing = true;

    try {
      this.lastSubmittedToolName = req.tool;
      const toolResult = await this.coreService.runToolCall({
        id: req.id,
        tool: req.tool,
        args: req.args,
        reason: req.reason,
        executionMode: req.executionMode
      });

      const resItem = new DisplayItem(DisplayItemType.AIToolResult, toolResult.id);
      resItem.toolRes = toolResult;
      this.displayItems.push(resItem);
      this.markProposalApplied(req, toolResult);
      this.scrollToBottom();

      // 2. 二段回灌给 AI
      const result2 = await AIService.getInstance().continueAfterTool(
        this.toolOriginalUserText || '',
        toolResult,
        i18n.System.getSystemLanguage(),
        this.buildSessionContextString(),
        this.sessionSummary
      );

      if (result2.sessionSummary) {
        this.sessionSummary = result2.sessionSummary.substring(0, 600);
      }

      if (await this.handleToolCalls(result2, this.toolOriginalUserText || '')) {
        return;
      }
      this.appendResultToUI(result2);
      this.clearProposalToolRequest(req.tool, req.id);

    } catch (err) {
      console.error("[AIPanelView] Tool Error:", JSON.stringify(err));
      const errItem = new DisplayItem(DisplayItemType.AIChat);
      errItem.text = `工具执行失败：${err instanceof Error ? err.message : '未知错误'}`;
      this.displayItems.push(errItem);
    } finally {
      this.repoBusy = false;
      this.isParsing = false;
      this.currentProgressHint = '';
      this.refreshMemoryState();
      this.scrollToBottom();
      this.emitSessionSnapshotChange();
    }
  }

  // ==========================================
  // MARK: - 上屏与上下文辅助
  // ==========================================

  private appendResultToUI(result: MixedResult) {
    if (result.newMemories) {
      for (const mem of result.newMemories) {
        const item = new DisplayItem(DisplayItemType.AIMemory);
        item.text = mem;
        this.displayItems.push(item);
      }
    }
    const suppressProposalCards = this.shouldSuppressProposalCards();
    if (result.tasks && !suppressProposalCards) {
      for (const task of result.tasks) {
        const item = new DisplayItem(DisplayItemType.AITask);
        item.task = task;
        this.displayItems.push(item);
      }
    }
    if (result.habits && !suppressProposalCards) {
      for (const habit of result.habits) {
        const item = new DisplayItem(DisplayItemType.AIHabit);
        item.habit = habit;
        this.displayItems.push(item);
      }
    }
    if (result.chatResponse) {
      const item = new DisplayItem(DisplayItemType.AIChat);
      item.text = result.chatResponse;
      this.displayItems.push(item);
    }
    this.lastSubmittedToolName = '';
    this.emitSessionSnapshotChange();
  }

  private async handleToolCalls(result: MixedResult, query: string): Promise<boolean> {
    if (!result.toolCalls || result.toolCalls.length === 0) {
      return false;
    }
    this.toolOriginalUserText = query;
    for (const call of result.toolCalls) {
      if (!call) {
        continue;
      }
      const toolReq: AIToolRequest = {
        id: call.id || util.generateRandomUUID(true),
        tool: call.tool,
        args: call.tool === 'read_tasks'
          ? sanitizeReadTasksArgs(call.args as ReadTasksArgs, query) as Object
          : call.args,
        reason: defaultToolReason(call.tool),
        executionMode: call.executionMode
      };

      const proposalHandled = this.presentToolRequestAsProposal(toolReq);
      if (proposalHandled) {
        const normalizedTool = toolReq.tool.toLowerCase();
        if (this.silentTaskAdd && (normalizedTool === 'create_task' || normalizedTool === 'create_habit')) {
          this.handleProgressUpdate('thinking', '已开启静默添加，正在自动提交本批创建。');
          await this.approveAndRunTool(toolReq);
        }
        continue;
      }

      if (toolReq.executionMode === 'AUTO') {
        await this.approveAndRunTool(toolReq);
      } else {
        const reqItem = new DisplayItem(DisplayItemType.AIToolRequest);
        reqItem.toolReq = toolReq;
        this.displayItems.push(reqItem);
      }
    }
    return true;
  }

  private shouldSuppressProposalCards(): boolean {
    return this.lastSubmittedToolName === 'read_tasks' ||
      this.lastSubmittedToolName === 'read_habits' ||
      this.lastSubmittedToolName === 'create_task' ||
      this.lastSubmittedToolName === 'create_habit';
  }

  private buildSessionContextString(maxChars: number = 1200): string {
    let lines: string[] = [];
    const recent = this.displayItems.slice(-20).reverse();

    for (const item of recent) {
      switch (item.type) {
        case DisplayItemType.UserQuery: lines.push(`User: ${item.text}`); break;
        case DisplayItemType.AIChat: lines.push(`AI: ${item.text}`); break;
        case DisplayItemType.AIThinking: lines.push(`Thinking: ${item.text}`); break;
        case DisplayItemType.AITask: lines.push(`PendingTask: ${item.task?.name} | due=${item.task?.dueTime || "无"}`); break;
        case DisplayItemType.AIHabit: lines.push(`PendingHabit: ${item.habit?.name} | ${item.habit?.period} x${item.habit?.timesPerPeriod}`); break;
        case DisplayItemType.AIMemory: lines.push(`MemoryCaptured: ${item.text}`); break;
        case DisplayItemType.AIToolRequest: lines.push(`ToolRequest: ${item.toolReq?.tool}`); break;
        case DisplayItemType.AIToolResult: lines.push(`ToolResult: ${toolResultSummary(item.toolRes as AIToolResult)}`); break;
      }
      if (lines.join("\n").length > maxChars) break;
    }
    return lines.reverse().join("\n");
  }

  // ==========================================
  // MARK: - 任务创建
  // ==========================================

  async createTaskFromProposal(task: AITask) {
    if (this.repoBusy) return;
    try {
      const linkedReq = this.findTaskProposalToolRequest(task);
      if (linkedReq) {
        await this.approveAndRunTool(linkedReq);
        return;
      }
      this.repoBusy = true;
      // 显示二次确认 Dialog
      AlertDialog.show({
        title: '确认创建任务？',
        message: `任务：${task.name}\n截止：${task.dueTime || '无'}`,
        primaryButton: {
          value: '取消',
          fontColor: $r('app.color.warning'),
          action: () => { this.repoBusy = false; }
        },
        secondaryButton: {
          value: '创建',
          fontColor: this.theme.accent,
          action: async () => {
            const now = new Date();
            const parsedEnd = task.dueTime ? DateTimeUtils.parseDateString(task.dueTime) : null;
            const end = parsedEnd ?? new Date(now.getTime() + 60 * 60 * 1000);

            await TaskRepository.getInstance().insertDDL({
              name: task.name,
              note: task.note || "",
              startTime: DateTimeUtils.toLocalISOString(now),
              endTime: DateTimeUtils.toLocalISOString(end),
              isCompleted: false,
              completeTime: "",
              isArchived: false,
              isStared: false,
              type: DeadlineType.TASK,
              calendarEventId: null
            });

            this.addedTaskKeys.push(makeTaskKey(task));

            const item = new DisplayItem(DisplayItemType.AIChat);
            item.text = `已添加任务：${task.name}`;
            this.displayItems.push(item);
            this.scrollToBottom();
            this.repoBusy = false;
            this.emitSessionSnapshotChange();
          }
        }
      });
    } catch (err) {
      this.repoBusy = false;
    }
  }

  // ==========================================
  // MARK: - UI 构建
  // ==========================================

  scrollToBottom() {
    setTimeout(() => { this.scroller.scrollEdge(Edge.Bottom); }, 150);
  }

  @Builder
  MemoryHintView() {
    Row() {
      SymbolGlyph($r('sys.symbol.small_head'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_secondary')])
        .margin({ right: 6 })

      Text(`画像: ${this.hasUserProfile ? '已建立' : '未建立'} · 记忆 ${this.memoryFragmentCount} 条`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
    .margin({ bottom: 16 })
    .onClick(() => {
      this.showMemorySheet = true;
    })
  }

  @Builder
  InitialGuideView() {
    Column({ space: 16 }) {
      // Avatar
      Stack() {
        Circle().width(78).height(78).fillOpacity(0.1).fill(this.theme.brand)
        Symbol({
          icon: $r('app.media.lifi'),
          isImage: true,
          fontSize: 30,
          fontColor: this.theme.brand
        })
      }
      .margin({ top: 40 })

      Text('Lifi AI')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
      Text('一句话生成任务 / 习惯 / 记忆')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ bottom: 20 })

      // Quick Actions
      this.QuickRow("创建任务", "明天 19:00 交系统论作业", $r('sys.symbol.checkmark_circle_fill'))
      this.QuickRow("创建习惯", "每周 3 次 跑步 30 分钟", $r('sys.symbol.arrow_clockwise'))
    }
    .width('100%')
    .padding(24)
  }

  @Builder
  QuickRow(title: string, subtitle: string, icon: Resource) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(20).fontColor([this.theme.brand])
      Column() {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium)
        Text(subtitle).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(16)
    .onClick(() => {
      this.runSmartAgent(subtitle);
    })
  }

  @Builder
  RealAIContent() {
    Column() {
      // 核心滚动区域
      List({ scroller: this.scroller }) {
        ListItem() {
          Column().height(this.topAvoidHeight)
        }

        ListItem() {
          if (this.displayItems.length === 0) {
            this.InitialGuideView()
          } else {
            Column() {
              if (!this.isReadonlyHistoryMode) {
                this.MemoryHintView()
              }

              ForEach(this.displayItems, (item: DisplayItem) => {
                this.RenderItem(item)
              }, (item: DisplayItem) => item.id)

              if (this.isParsing) {
                Row({ space: 8 }) {
                  LoadingProgress().width(16).height(16).color(this.theme.brand)
                  Text(this.currentProgressHint || "Deadliner 正在思考...").fontSize(12).fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')
                .padding({ left: 16, top: 8, bottom: 8 })
              }
            }
            .padding({ left: 16, right: 16 })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .alignListItem(ListItemAlign.Center)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 输入区域
      Row() {
        TextInput({
          text: $$this.inputText,
          placeholder: this.isReadonlyHistoryMode ? '历史对话仅供查看，请新建对话继续' : '告诉 Deadliner 你的计划...'
        })
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(20)
          .height(40)
          .enabled(!this.isParsing && !this.isReadonlyHistoryMode)
          .onSubmit(() => { this.runSmartAgent() })

        Button({ type: ButtonType.Circle }) {
          if (this.isParsing) {
            SymbolGlyph($r('sys.symbol.loading')).fontSize(20).fontColor([$r('sys.color.icon_on_primary')])
          } else {
            SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(20).fontColor([$r('sys.color.icon_on_primary')])
          }
        }
        .width(40).height(40).margin({ left: 12 })
        .backgroundColor((this.inputText.trim().length > 0 && !this.isParsing && !this.isReadonlyHistoryMode) ? this.theme.brand : $r('sys.color.comp_background_tertiary'))
        .enabled(!this.isParsing && !this.isReadonlyHistoryMode && this.inputText.trim().length > 0)
        .onClick(() => { this.runSmartAgent() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 36 + this.bottomPadding })
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  RenderItem(item: DisplayItem) {
    if (item.type === DisplayItemType.UserQuery) {
      Row() {
        Blank()
        Text(item.text).fontSize(16).fontColor($r('sys.color.font_on_primary')).backgroundColor(this.theme.brand)
          .padding(12).borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 4 })
      }.width('100%').padding({ top: 8, bottom: 8 })
    }
    else if (item.type === DisplayItemType.AIChat) {
      Row() {
        Text(item.text).fontSize(16).fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .padding(12).borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 16 })
        Blank()
      }.width('100%').padding({ top: 8, bottom: 8 })
    }
    else if (item.type === DisplayItemType.AIThinking) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.data')).fontSize(14).fontColor([this.theme.brand])
        Text(item.text).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Blank()
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#100A59F7')
      .borderRadius(16)
      .margin({ top: 4, bottom: 4 })
    }
    else if (item.type === DisplayItemType.AIMemory) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.small_head')).fontSize(14).fontColor([Color.Pink])
        Text(`记住了：${item.text}`).fontSize(12).fontColor($r('sys.color.font_secondary')).fontStyle(FontStyle.Italic)
        Blank()
      }
      .width('100%').padding(12).backgroundColor('#10800080').borderRadius(10).margin({ top: 4, bottom: 4 })
    }
    else if (item.type === DisplayItemType.AITask && item.task) {
      this.ProposalCard(item.task)
    }
    else if (item.type === DisplayItemType.AIHabit && item.habit) {
      this.HabitCard(item.habit)
    }
    else if (item.type === DisplayItemType.AIToolRequest && item.toolReq) {
      this.ToolRequestCard(item.toolReq)
    }
    else if (item.type === DisplayItemType.AIToolResult && item.toolRes) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.data')).fontSize(14).fontColor([Color.Orange])
        Text(toolResultSummary(item.toolRes))
          .fontSize(12).fontColor($r('sys.color.font_secondary'))
        Blank()
      }.width('100%').padding(12).backgroundColor('#10FFA500').borderRadius(10).margin({ top: 4, bottom: 4 })
    }
  }

  @Builder
  ProposalCard(task: AITask) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.doc_text_fill')).fontSize(14).fontColor([this.theme.accent])
        Text("识别到任务").fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        Blank()
      }.width('100%')

      Text(task.name).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
      if (task.dueTime) {
        Text(task.dueTime).fontSize(14).fontColor(this.theme.accent).width('100%')
      }

      Button(this.addedTaskKeys.includes(makeTaskKey(task)) ? "已添加" : "确认添加")
        .type(ButtonType.Normal)
        .borderRadius(24)
        .width('100%')
        .backgroundColor(this.addedTaskKeys.includes(makeTaskKey(task)) ? $r('sys.color.comp_background_tertiary') : this.theme.accent)
        .fontColor(this.addedTaskKeys.includes(makeTaskKey(task)) ? $r('sys.color.font_secondary') : Color.White)
        .enabled(!this.addedTaskKeys.includes(makeTaskKey(task)) && !this.repoBusy)
        .onClick(() => { this.createTaskFromProposal(task); })
        .margin({ top: 8 })
    }
    .width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(16).margin({ top: 8, bottom: 8 })
  }

  @Builder
  ToolRequestCard(req: AIToolRequest) {
    Column({ space: 12 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.archivebox')).fontSize(14).fontColor([Color.Orange])
        Text(toolDisplayTitle(req.tool)).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        Blank()
      }.width('100%')

      Text(req.reason || defaultToolReason(req.tool)).fontSize(14).fontColor($r('sys.color.font_primary')).width('100%')

      Text(toolArgsSummary(req))
        .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')

      if (req.tool === 'create_task' || req.tool === 'create_habit') {
        Scroll(this.scroller) {
          Text(toolArgsDetail(req))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .height(140)
        .width('100%')
        .padding(10)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(12)
      }

      Row({ space: 12 }) {
        Button("拒绝")
          .type(ButtonType.Normal).borderRadius(24).layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary')).fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            const item = new DisplayItem(DisplayItemType.AIChat);
            item.text = "好的，这次我不执行这个本地操作。你也可以提供更明确的信息让我继续。";
            this.displayItems.push(item);
            this.scrollToBottom();
            this.emitSessionSnapshotChange();
          })

        Button("允许一次")
          .type(ButtonType.Normal).borderRadius(24).layoutWeight(1)
          .backgroundColor(this.theme.brand).fontColor(Color.White)
          .enabled(!this.repoBusy)
          .onClick(() => { this.approveAndRunTool(req); })
      }.width('100%')
    }
    .width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(16).margin({ top: 8, bottom: 8 })
  }

  @Builder
  memoryManageSheet() {
    MemoryManageSheet({
      onDismiss: () => {
        this.showMemorySheet = false
      },
      onDataChanged: () => {
        this.refreshMemoryState();
      }
    })
  }

  // ==========================================
  // MARK: - Habit 专属 UI 与逻辑
  // ==========================================

  async createHabitFromProposal(habit: AIHabit) {
    if (this.repoBusy) return;

    try {
      const linkedReq = this.findHabitProposalToolRequest(habit);
      if (linkedReq) {
        await this.approveAndRunTool(linkedReq);
        return;
      }
      this.repoBusy = true;
      // 1. 映射 Period (周期) 到 pIndex
      let pIndex = 0; // 默认 DAILY
      if (habit.period === 'WEEKLY') pIndex = 1;
      else if (habit.period === 'MONTHLY') pIndex = 2;

      // 2. 映射 GoalType (目标类型) 到 gIndex，并提取 totalTarget
      let gIndex = 0; // 默认 PER_PERIOD
      let totalStr = "";
      if (habit.goalType === 'TOTAL') {
        gIndex = 1;
        if (habit.totalTarget !== undefined && habit.totalTarget !== null) {
          totalStr = habit.totalTarget.toString();
        }
      }

      // 3. 提取单次频率
      const timesStr = habit.timesPerPeriod ? habit.timesPerPeriod.toString() : "1";

      // 4. 调用现成的 Helper 逻辑进行保存
      // 注意：HabitFormHelper 内部已经处理了 Toast 提示和 DDL 插入逻辑
      const isSuccess = await HabitFormHelper.saveNewHabit(
        habit.name,
        pIndex,
        gIndex,
        timesStr,
        totalStr
      );

      // 5. 只有保存成功，才更新界面的 AI 聊天流和按钮状态
      if (isSuccess) {
        this.addedHabitKeys.push(makeHabitKey(habit));
        const item = new DisplayItem(DisplayItemType.AIChat);
        item.text = `已开启习惯：${habit.name}`;
        this.displayItems.push(item);
        this.scrollToBottom();
        this.emitSessionSnapshotChange();
      }

    } catch (err) {
      console.error("[AIPanelView] 创建习惯失败", JSON.stringify(err));
    } finally {
      this.repoBusy = false;
    }
  }

  @Builder
  HabitCard(habit: AIHabit) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(14).fontColor([this.theme.accent])
        Text("识别到习惯").fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        Blank()
      }.width('100%')

      Text(habit.name).fontSize(16).fontWeight(FontWeight.Medium).width('100%')

      Text(`${habit.period} / ${habit.timesPerPeriod}次`)
        .fontSize(14).fontColor(this.theme.accent).width('100%')

      Button(this.addedHabitKeys.includes(makeHabitKey(habit)) ? "已开启" : "开启习惯")
        .type(ButtonType.Normal)
        .borderRadius(24)
        .width('100%')
        .backgroundColor(this.addedHabitKeys.includes(makeHabitKey(habit)) ? $r('sys.color.comp_background_tertiary') : this.theme.accent)
        .fontColor(this.addedHabitKeys.includes(makeHabitKey(habit)) ? $r('sys.color.font_secondary') : Color.White)
        .enabled(!this.addedHabitKeys.includes(makeHabitKey(habit)) && !this.repoBusy)
        .onClick(() => { this.createHabitFromProposal(habit); })
        .margin({ top: 8 })
    }
    .width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(16).margin({ top: 8, bottom: 8 })
  }

  private handleProgressUpdate(kind: string, message: string) {
    if (!message || message.length === 0) {
      return;
    }
    this.currentProgressHint = message;
    if (!this.shouldAppendThinkingMessage(message)) {
      return;
    }
    const item = new DisplayItem(DisplayItemType.AIThinking);
    item.text = message;
    this.displayItems.push(item);
    this.scrollToBottom();
    this.emitSessionSnapshotChange();
  }

  private shouldAppendThinkingMessage(message: string): boolean {
    const lastItem = this.displayItems.length > 0 ? this.displayItems[this.displayItems.length - 1] : undefined;
    if (!lastItem || lastItem.type !== DisplayItemType.AIThinking) {
      return true;
    }
    return lastItem.text !== message;
  }

  private presentToolRequestAsProposal(req: AIToolRequest): boolean {
    if (req.tool === 'create_task') {
      const proposals = taskProposalsFromToolRequest(req);
      if (proposals.length === 0) {
        return false;
      }
      if (proposals.length > 1) {
        return false;
      }
      for (const proposal of proposals) {
        this.taskProposalToolRequests.push(new ProposalToolRequestLink(makeTaskKey(proposal), req));
        const item = new DisplayItem(DisplayItemType.AITask);
        item.task = proposal;
        this.displayItems.push(item);
      }
      this.handleProgressUpdate('thinking', `Deadliner 已经整理好 ${proposals.length} 个待创建任务。`);
      return true;
    }
    if (req.tool === 'create_habit') {
      const proposals = habitProposalsFromToolRequest(req);
      if (proposals.length === 0) {
        return false;
      }
      if (proposals.length > 1) {
        return false;
      }
      for (const proposal of proposals) {
        this.habitProposalToolRequests.push(new ProposalToolRequestLink(makeHabitKey(proposal), req));
        const item = new DisplayItem(DisplayItemType.AIHabit);
        item.habit = proposal;
        this.displayItems.push(item);
      }
      this.handleProgressUpdate('thinking', `Deadliner 已经整理好 ${proposals.length} 个待创建习惯。`);
      return true;
    }
    return false;
  }

  private findTaskProposalToolRequest(task: AITask): AIToolRequest | null {
    const key = makeTaskKey(task);
    const found = this.taskProposalToolRequests.find((item) => item.key === key);
    return found ? found.request : null;
  }

  private findHabitProposalToolRequest(habit: AIHabit): AIToolRequest | null {
    const key = makeHabitKey(habit);
    const found = this.habitProposalToolRequests.find((item) => item.key === key);
    return found ? found.request : null;
  }

  private clearProposalToolRequest(toolName: string, requestId: string) {
    if (toolName === 'create_task') {
      this.taskProposalToolRequests = this.taskProposalToolRequests.filter((item) => item.request.id !== requestId);
    }
    if (toolName === 'create_habit') {
      this.habitProposalToolRequests = this.habitProposalToolRequests.filter((item) => item.request.id !== requestId);
    }
  }

  private markProposalApplied(req: AIToolRequest, result: AIToolResult) {
    if (req.tool === 'create_task') {
      const proposals = taskProposalsFromToolRequest(req);
      const payload = result.payload as AdapterCreateTaskPayload;
      const successCount = payload.summary?.successCount ?? (payload.ok ? proposals.length : 0);
      for (let index = 0; index < Math.min(successCount, proposals.length); index++) {
        const key = makeTaskKey(proposals[index]);
        if (!this.addedTaskKeys.includes(key)) {
          this.addedTaskKeys.push(key);
        }
      }
      return;
    }

    if (req.tool === 'create_habit') {
      const proposals = habitProposalsFromToolRequest(req);
      const payload = result.payload as AdapterCreateHabitPayload;
      const successCount = payload.summary?.successCount ?? (payload.ok ? proposals.length : 0);
      for (let index = 0; index < Math.min(successCount, proposals.length); index++) {
        const key = makeHabitKey(proposals[index]);
        if (!this.addedHabitKeys.includes(key)) {
          this.addedHabitKeys.push(key);
        }
      }
    }
  }

  build() {
    Column() {
      if (this.isLoggedIn || this.bypassHuaweiLogin) {
        this.RealAIContent()
      } else {
        LoginPanelView()
      }
    }
    .width('100%').height('100%')
    .bindSheet($$this.showMemorySheet, this.memoryManageSheet(), {
      detents: [ 550, 900 ],
      height: 550,
      dragBar: true,
      enableFloatingDragBar: true,
      enableOutsideInteractive: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      onDisappear: () => {
        this.showMemorySheet = false;
        this.refreshMemoryState();
      },
      // blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      showClose: false
    })
  }
}

@Component
export struct AIPanelView {
  @Prop bypassHuaweiLogin: boolean = false;
  @Prop topAvoidHeight: number = 0;
  @Prop bottomPadding: number = 0;
  @Prop startNewChatSignal: number = 0;
  @Require onDismissPanel: () => void;

  build() {
    AIWorkspaceView({
      bypassHuaweiLogin: this.bypassHuaweiLogin,
      topAvoidHeight: this.topAvoidHeight,
      bottomPadding: this.bottomPadding,
      startNewChatSignal: this.startNewChatSignal,
      onSessionSnapshotChange: (_snapshot: AIWorkspaceSessionSnapshot): void => {}
    })
      .width('100%')
      .height('100%')
  }
}
