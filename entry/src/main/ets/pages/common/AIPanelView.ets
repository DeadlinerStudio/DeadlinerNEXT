import { i18n } from '@kit.LocalizationKit';
import util from '@ohos.util';
import {
  AITask,
  AIHabit,
  AIToolRequest,
  AIToolResult,
  ReadTasksArgs,
  ReadTasksResultPayload,
  TaskDigestItem,
  TaskSummary,
  MixedResult
} from '../../ai/model/AIModels';
import { ITheme } from '../../common/theme/ThemeModel';
import { AddTaskParams } from '../routes/main/modify/task/AddTaskPage';
import { LoginPanelView } from './LoginPanelView';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { DateTimeUtils } from '../../utils/DateTimeUtils';
import { DeadlineType, DDLItem } from '../../model/DDLModels';
import { MemoryBank } from '../../ai/model/MemoryModels';
import { AIService } from '../../ai/AIServcice';
import { MemoryManageSheet } from './MemoryManageSheet';
import { HabitFormHelper } from '../routes/main/modify/habit/HabitFormHelper';
import { Symbol } from '../components/infra/Symbol';

// ==========================================
// MARK: - 对话流模型定义
// ==========================================
export enum DisplayItemType {
  UserQuery,
  AIChat,
  AITask,
  AIHabit,
  AIMemory,
  AIToolRequest,
  AIToolResult
}

@Observed
export class DisplayItem {
  id: string;
  type: DisplayItemType;
  text?: string;
  task?: AITask;
  habit?: AIHabit;
  toolReq?: AIToolRequest;
  toolRes?: AIToolResult;

  constructor(type: DisplayItemType, id?: string) {
    this.type = type;
    this.id = id || util.generateRandomUUID(true);
  }
}

interface TaskAIDTO {
  ddl: DDLItem;
  due: Date;
}

// ==========================================
// MARK: - 核心 UI 组件
// ==========================================

@Component
export struct AIPanelView {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp(C.KEY_DIRECT_ADD_ON_AI) directAdd: boolean = true;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @Require onDismissPanel: () => void;

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

  private scroller: Scroller = new Scroller();
  private toolOriginalUserText: string = "";

  @State showMemorySheet: boolean = false;

  @State hasUserProfile: boolean = false;
  @State memoryFragmentCount: number = 0;

  aboutToAppear() {
    // 初始化记忆银行并触发 UI 更新
    MemoryBank.getInstance().init(getContext(this)).then(() => {
      this.refreshMemoryState();
    });
  }

  private refreshMemoryState() {
    const mb = MemoryBank.getInstance();
    this.hasUserProfile = mb.userProfile.trim().length > 0;
    this.memoryFragmentCount = mb.fragments.length;
    this.memoryProfileCount = mb.fragments.length + (this.hasUserProfile ? 1 : 0);
  }

  // ==========================================
  // MARK: - 业务逻辑 (Agent Core)
  // ==========================================

  async runSmartAgent(textToRun?: string) {
    const query = (textToRun || this.inputText).trim();
    if (!query || this.isParsing) return;

    // 1. 上屏用户消息
    const userItem = new DisplayItem(DisplayItemType.UserQuery);
    userItem.text = query;
    this.displayItems.push(userItem);
    this.inputText = '';
    this.isParsing = true;
    this.scrollToBottom();

    try {
      const sysLang = i18n.System.getSystemLanguage();
      const sessionCtx = this.buildSessionContextString();

      const result = await AIService.getInstance().processInput(
        query, sysLang, sessionCtx, this.sessionSummary
      );

      if (result.sessionSummary) {
        this.sessionSummary = result.sessionSummary.substring(0, 600);
      }

      // 2. 拦截 Tool Call (目前只处理 readTasks)
      if (result.toolCalls && result.toolCalls.length > 0) {
        this.isParsing = false;
        const firstCall = result.toolCalls.find(c => c.tool === "readTasks");

        if (firstCall) {
          this.toolOriginalUserText = query;
          const reqItem = new DisplayItem(DisplayItemType.AIToolRequest);
          reqItem.toolReq = {
            id: util.generateRandomUUID(true),
            tool: "readTasks",
            args: this.sanitizeReadTasksArgs(firstCall.args, query),
            reason: firstCall.reason
          };
          this.displayItems.push(reqItem);
        } else {
          const chatItem = new DisplayItem(DisplayItemType.AIChat);
          chatItem.text = "我需要调用一个暂不支持的本地工具。请更新版本或换个问法。";
          this.displayItems.push(chatItem);
        }
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
      if (req.tool !== "readTasks") {
        const errItem = new DisplayItem(DisplayItemType.AIChat);
        errItem.text = `暂不支持的工具：${req.tool}`;
        this.displayItems.push(errItem);
        return;
      }

      // 1. 执行本地查询
      const ddlTasks = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);
      const payload = this.makeReadTasksPayload(ddlTasks, req.args);

      const toolResult: AIToolResult = {
        id: util.generateRandomUUID(true),
        tool: "readTasks",
        appliedArgs: req.args,
        payload: payload,
        generatedAt: new Date()
      };

      const resItem = new DisplayItem(DisplayItemType.AIToolResult, toolResult.id);
      resItem.toolRes = toolResult;
      this.displayItems.push(resItem);
      this.scrollToBottom();

      // 2. 二段回灌给 AI
      const sysLang = i18n.System.getSystemLanguage();
      const sessionCtx = this.buildSessionContextString();
      const originalText = this.toolOriginalUserText || "（用户未提供原始问题）";

      const result2 = await AIService.getInstance().continueAfterTool(
        originalText, toolResult, sysLang, sessionCtx, this.sessionSummary
      );

      if (result2.sessionSummary) {
        this.sessionSummary = result2.sessionSummary.substring(0, 600);
      }

      this.appendResultToUI(result2);

    } catch (err) {
      console.error("[AIPanelView] Tool Error:", JSON.stringify(err));
      const errItem = new DisplayItem(DisplayItemType.AIChat);
      errItem.text = `工具执行失败：${err instanceof Error ? err.message : '未知错误'}`;
      this.displayItems.push(errItem);
    } finally {
      this.repoBusy = false;
      this.isParsing = false;
      this.refreshMemoryState();
      this.scrollToBottom();
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
    if (result.tasks) {
      for (const task of result.tasks) {
        const item = new DisplayItem(DisplayItemType.AITask);
        item.task = task;
        this.displayItems.push(item);
      }
    }
    if (result.habits) {
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
  }

  private buildSessionContextString(maxChars: number = 1200): string {
    let lines: string[] = [];
    const recent = this.displayItems.slice(-20).reverse();

    for (const item of recent) {
      switch (item.type) {
        case DisplayItemType.UserQuery: lines.push(`User: ${item.text}`); break;
        case DisplayItemType.AIChat: lines.push(`AI: ${item.text}`); break;
        case DisplayItemType.AITask: lines.push(`PendingTask: ${item.task?.name} | due=${item.task?.dueTime || "无"}`); break;
        case DisplayItemType.AIHabit: lines.push(`PendingHabit: ${item.habit?.name} | ${item.habit?.period} x${item.habit?.timesPerPeriod}`); break;
        case DisplayItemType.AIMemory: lines.push(`MemoryCaptured: ${item.text}`); break;
        case DisplayItemType.AIToolRequest: lines.push(`ToolRequest: ${item.toolReq?.tool}`); break;
        case DisplayItemType.AIToolResult: lines.push(`ToolResult: ${item.toolRes?.tool} count=${item.toolRes?.payload.summary.count}`); break;
      }
      if (lines.join("\n").length > maxChars) break;
    }
    return lines.reverse().join("\n");
  }

  // ==========================================
  // MARK: - 工具数据处理 (Tool Call)
  // ==========================================

  private sanitizeReadTasksArgs(args: ReadTasksArgs, userQuery: string): ReadTasksArgs {
    const days = Math.max(1, Math.min(args.timeRangeDays ?? 7, 30));
    const limit = Math.max(1, Math.min(args.limit ?? 20, 50));
    const status = (args.status ?? "OPEN").toUpperCase();
    const sort = (args.sort ?? "DUE_ASC").toUpperCase();

    // 清洗 AI 提取的关键词
    let kws = (args.keywords ?? [])
      .map(k => k.trim())
      .filter(k => k.length > 0)
      .slice(0, 3)
      .map(k => k.substring(0, 12));

    const q = userQuery.toLowerCase();
    kws = kws.filter(k => q.includes(k.toLowerCase()));

    // 泛查询屏蔽关键词
    const patterns = ["这周", "本周", "最近", "有哪些任务", "有什么任务", "任务列表", "to do", "todo", "待办", "待办事项", "deadline", "ddl"];
    const isGeneric = patterns.some(p => q.includes(p));
    const explicitSignals = ["关于", "相关", "的任务", "的ddl", "的待办", "项目", "course", "project"];
    const hasTopic = explicitSignals.some(s => q.includes(s));

    if (isGeneric && !hasTopic) {
      kws = [];
    }

    return { timeRangeDays: days, status, keywords: kws, limit, sort };
  }

  private makeReadTasksPayload(items: DDLItem[], args: ReadTasksArgs): ReadTasksResultPayload {
    const now = new Date();
    const days = args.timeRangeDays ?? 7;
    const endMs = now.getTime() + (days * 86400 * 1000);
    const keywords = (args.keywords ?? []).map(k => k.toLowerCase());
    const wantStatus = (args.status ?? "OPEN").toUpperCase();

    // 1. 过滤
    let filteredItems: TaskAIDTO[] = [];

    for (const t of items) {
      if (t.isArchived) continue;
      if (wantStatus === "OPEN" && t.isCompleted) continue;
      if (wantStatus === "DONE" && !t.isCompleted) continue;

      const dueStr = t.endTime?.trim();
      if (!dueStr) continue; // 没有截止时间的不纳入未来范围计算

      const due = DateTimeUtils.parseDateString(dueStr);
      if (!due) continue;
      if (due.getTime() < now.getTime() - 365 * 86400 * 1000) continue; // 极端脏数据
      if (due.getTime() > endMs) continue; // 超过查询范围

      if (keywords.length > 0) {
        const hay = `${t.name} ${t.note || ''}`.toLowerCase();
        const hit = keywords.some(k => hay.includes(k));
        if (!hit) continue;
      }

      filteredItems.push({ ddl: t, due });
    }

    // 2. 排序
    const sort = (args.sort ?? "DUE_ASC").toUpperCase();
    filteredItems.sort((a, b) => {
      return sort === "UPDATED_DESC"
        ? b.due.getTime() - a.due.getTime()
        : a.due.getTime() - b.due.getTime();
    });

    // 3. Limit
    const limit = args.limit ?? 20;
    if (filteredItems.length > limit) {
      filteredItems = filteredItems.slice(0, limit);
    }

    // 4. 统计 Summary
    let overdue = 0;
    let dueSoon24h = 0;
    for (const item of filteredItems) {
      const due = item.due
      if (due.getTime() < now.getTime()) overdue++;
      else if (due.getTime() <= now.getTime() + 86400 * 1000) dueSoon24h++;
    }

    const digestTasks: TaskDigestItem[] = filteredItems.map((item): TaskDigestItem => ({
      id: typeof item.ddl.id === 'number' ? item.ddl.id : 0,
      name: item.ddl.name,
      due: item.ddl.endTime || "",
      status: item.ddl.isCompleted ? "DONE" : "OPEN",
      notePreview: (item.ddl.note || "").substring(0, 40)
    }));

    return {
      tasks: digestTasks,
      summary: { count: digestTasks.length, overdue, dueSoon24h }
    };
  }

  // ==========================================
  // MARK: - 任务创建
  // ==========================================

  private makeTaskKey(task: AITask): string {
    return `${task.name}#${task.dueTime || 'none'}`;
  }

  private makeHabitKey(habit: AIHabit): string {
    return `${habit.name}#${habit.period}#${habit.timesPerPeriod}`;
  }

  async createTaskFromProposal(task: AITask) {
    if (this.repoBusy) return;
    this.repoBusy = true;
    try {
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
              endTime: task.dueTime ? DateTimeUtils.toLocalISOString(end) : "",
              isCompleted: false,
              completeTime: "",
              isArchived: false,
              isStared: false,
              type: DeadlineType.TASK,
              calendarEventId: null
            });

            this.addedTaskKeys.push(this.makeTaskKey(task));

            const item = new DisplayItem(DisplayItemType.AIChat);
            item.text = `已添加任务：${task.name}`;
            this.displayItems.push(item);
            this.scrollToBottom();
            this.repoBusy = false;
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

      Text('Deadliner Agent')
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
          if (this.displayItems.length === 0) {
            this.InitialGuideView()
          } else {
            Column() {
              this.MemoryHintView()

              ForEach(this.displayItems, (item: DisplayItem) => {
                this.RenderItem(item)
              }, (item: DisplayItem) => item.id)

              if (this.isParsing) {
                Row({ space: 8 }) {
                  LoadingProgress().width(16).height(16).color(this.theme.brand)
                  Text("Deadliner 正在思考...").fontSize(12).fontColor($r('sys.color.font_secondary'))
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

      // 输入区域
      Row() {
        TextInput({ text: $$this.inputText, placeholder: '告诉 Deadliner 你的计划...' })
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(20)
          .height(40)
          .enabled(!this.isParsing)
          .onSubmit(() => { this.runSmartAgent() })

        Button({ type: ButtonType.Circle }) {
          if (this.isParsing) {
            SymbolGlyph($r('sys.symbol.loading')).fontSize(20).fontColor([$r('sys.color.icon_on_primary')])
          } else {
            SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(20).fontColor([$r('sys.color.icon_on_primary')])
          }
        }
        .width(40).height(40).margin({ left: 12 })
        .backgroundColor((this.inputText.trim().length > 0 && !this.isParsing) ? this.theme.brand : $r('sys.color.comp_background_tertiary'))
        .enabled(!this.isParsing && this.inputText.trim().length > 0)
        .onClick(() => { this.runSmartAgent() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 36 })
    }
    .width('100%').height('100%')
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
        Text(`已读取任务：${item.toolRes.payload.summary.count} 条（逾期 ${item.toolRes.payload.summary.overdue}）`)
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

      Button(this.addedTaskKeys.includes(this.makeTaskKey(task)) ? "已添加" : "确认添加")
        .type(ButtonType.Normal)
        .borderRadius(24)
        .width('100%')
        .backgroundColor(this.addedTaskKeys.includes(this.makeTaskKey(task)) ? $r('sys.color.comp_background_tertiary') : this.theme.accent)
        .fontColor(this.addedTaskKeys.includes(this.makeTaskKey(task)) ? $r('sys.color.font_secondary') : Color.White)
        .enabled(!this.addedTaskKeys.includes(this.makeTaskKey(task)) && !this.repoBusy)
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
        Text("需要读取任务列表").fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        Blank()
      }.width('100%')

      Text(req.reason || "为了回答你的问题，我需要查看你近期的任务。").fontSize(14).fontColor($r('sys.color.font_primary')).width('100%')

      Text(`范围：未来 ${req.args.timeRangeDays || 7} 天 · 状态：${req.args.status || "OPEN"}`)
        .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')

      Row({ space: 12 }) {
        Button("拒绝")
          .type(ButtonType.Normal).borderRadius(24).layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary')).fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            const item = new DisplayItem(DisplayItemType.AIChat);
            item.text = "好的，我不读取任务列表。你可以告诉我更具体的任务信息。";
            this.displayItems.push(item);
            this.scrollToBottom();
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
    this.repoBusy = true;

    try {
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
        this.addedHabitKeys.push(this.makeHabitKey(habit));
        const item = new DisplayItem(DisplayItemType.AIChat);
        item.text = `已开启习惯：${habit.name}`;
        this.displayItems.push(item);
        this.scrollToBottom();
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

      Button(this.addedHabitKeys.includes(this.makeHabitKey(habit)) ? "已开启" : "开启习惯")
        .type(ButtonType.Normal)
        .borderRadius(24)
        .width('100%')
        .backgroundColor(this.addedHabitKeys.includes(this.makeHabitKey(habit)) ? $r('sys.color.comp_background_tertiary') : this.theme.accent)
        .fontColor(this.addedHabitKeys.includes(this.makeHabitKey(habit)) ? $r('sys.color.font_secondary') : Color.White)
        .enabled(!this.addedHabitKeys.includes(this.makeHabitKey(habit)) && !this.repoBusy)
        .onClick(() => { this.createHabitFromProposal(habit); })
        .margin({ top: 8 })
    }
    .width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(16).margin({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      if (this.isLoggedIn) {
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