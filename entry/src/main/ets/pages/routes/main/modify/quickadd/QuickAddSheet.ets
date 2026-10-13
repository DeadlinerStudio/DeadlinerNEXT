import { AIService } from '../../../../../ai/AIServcice';
import { TaskRepository } from '../../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../../common/repository/HabitRepository';
import { DeadlineType, HabitPeriod, HabitGoalType } from '../../../../../model/DDLModels';
import { AddTaskSheet } from '../task/AddTaskSheet';
import { AddHabitSheet } from '../habit/AddHabitSheet';
import { QuickAddDraft, QuickAddModels, QuickAddRequest } from './QuickAddModels';
import { QuickAddModelService, QuickAddModelDownloadStatus, modelDownloadLabel } from './QuickAddModelService';

@Component
export struct QuickAddSheet {
  onDone: () => void = () => {};
  initialKind: string = 'TASK';
  @State input: string = '';
  @State draft: QuickAddDraft = new QuickAddDraft();
  @State expanded: boolean = false;
  @State loading: boolean = false;
  @State saving: boolean = false;
  @State message: string = '';
  @State modelStatus: QuickAddModelDownloadStatus = new QuickAddModelDownloadStatus();
  private modelTimer: number = -1;
  private revision: number = 0;
  private timer: number = -1;
  private active: boolean = true;

  aboutToAppear(): void {
    this.active = true; this.draft.kind = this.initialKind;
    void this.prepareModel();
    void this.pollModelStatus();
  }
  private async prepareModel(): Promise<void> {
    const ready: boolean = await QuickAddModelService.prepare(getContext(this));
    if (ready && this.active && !this.expanded && !this.saving && !this.loading && this.draft.source === 'LOCAL' && this.input.length > 0) {
      this.updateInput(this.input);
    }
  }
  private async pollModelStatus(): Promise<void> {
    try {
      const status: QuickAddModelDownloadStatus = await QuickAddModelService.status();
      if (this.active && !this.expanded) this.modelStatus = status;
    } catch (_) { /* Keep rules if the model bridge is unavailable. */ }
    if (this.active && !this.expanded) this.modelTimer = setTimeout(() => { void this.pollModelStatus(); }, 300);
  }
  aboutToDisappear(): void {
    this.active = false; this.invalidate();
    if (this.modelTimer !== -1) clearTimeout(this.modelTimer);
  }
  private invalidate(): void {
    this.revision++;
    if (this.timer !== -1) { clearTimeout(this.timer); this.timer = -1; }
  }
  private updateInput(value: string): void {
    this.invalidate();
    this.input = value;
    this.loading = false;
    this.message = '';
    try {
      this.draft = QuickAddModels.parse(value, this.initialKind);
      if (QuickAddModelService.isReady() && value.length > 0) {
        this.draft = new QuickAddDraft();
        this.draft.kind = this.initialKind;
        this.draft.title = value;
        this.draft.source = 'MODEL';
        this.draft.needsAI = true;
        this.loading = true;
      }
      const version: number = this.revision;
      if (value.length > 0) this.timer = setTimeout(() => { void this.recognizeLocal(value, version); }, 100);
    } catch (_) {
      this.draft = new QuickAddDraft();
      this.message = '识别暂不可用，请更新核心或展开补充';
    }
  }
  private async recognizeLocal(value: string, version: number): Promise<void> {
    try {
      const local: QuickAddDraft | null = await QuickAddModelService.recognize(value, this.initialKind);
      if (!this.active || version !== this.revision || this.expanded || this.saving) return;
      if (local !== null) { this.draft = local; this.message = local.message; }
    } catch (_) { /* Keep the immediate rule proposal. */ }
    if (!this.active || version !== this.revision || this.expanded || this.saving) return;
    this.loading = false;
  }
  private recognizeWithAI(): void {
    if (this.input.length === 0 || this.saving || this.loading || this.expanded) return;
    this.invalidate();
    this.loading = true;
    const request: string = JSON.stringify(new QuickAddRequest(this.input, this.initialKind));
    void this.recognize(request, this.revision);
  }
  private async recognize(request: string, version: number): Promise<void> {
    try {
      const json: string = await AIService.getInstance().extractQuickAddJson(request);
      if (!this.active || version !== this.revision || this.expanded) return;
      const result: QuickAddDraft = JSON.parse(json);
      this.draft = result;
      this.message = result.message;
    } catch (_) {
      if (this.active && version === this.revision && !this.expanded) this.message = 'AI 识别失败，请修改输入或展开补充';
    } finally {
      if (this.active && version === this.revision && !this.expanded) this.loading = false;
    }
  }
  private period(): HabitPeriod {
    if (this.draft.period === 'WEEKLY') return HabitPeriod.WEEKLY;
    if (this.draft.period === 'MONTHLY') return HabitPeriod.MONTHLY;
    if (this.draft.period === 'EBBINGHAUS') return HabitPeriod.EBBINGHAUS;
    return HabitPeriod.DAILY;
  }
  private periodIndex(): number {
    if (this.draft.period === 'WEEKLY') return 1;
    if (this.draft.period === 'MONTHLY') return 2;
    if (this.draft.period === 'EBBINGHAUS') return 3;
    return 0;
  }
  private async save(): Promise<void> {
    if (!this.draft.ready || this.loading || this.saving) return;
    this.invalidate();
    this.saving = true;
    try {
      if (this.draft.kind === 'HABIT') {
        await HabitRepository.getInstance().createHabit(this.draft.title, this.period(), this.draft.targetCount,
          this.draft.period === 'TOTAL' ? HabitGoalType.TOTAL : HabitGoalType.PER_PERIOD,
          this.draft.period === 'TOTAL' ? this.draft.targetCount : null, this.draft.note,
          null, null, 0, this.draft.reminderTime, null, this.draft.weekdaysMask);
      } else {
        await TaskRepository.getInstance().insertDDL({
          name: this.draft.title, startTime: '', endTime: this.draft.dueAt ?? '', note: this.draft.note,
          isCompleted: false, completeTime: '', isArchived: false, isStared: false,
          type: DeadlineType.TASK, calendarEventId: null, categoryUid: null
        });
      }
      getContext(this).eventHub.emit('sync_done');
      this.onDone();
    } catch (_) { this.message = '保存失败，请重试'; this.saving = false; }
  }
  build() {
    if (this.expanded) {
      if (this.draft.kind === 'HABIT') {
        AddHabitSheet({ onDone: this.onDone, allowQuickAdd: false,
          initialName: this.draft.title || this.input, initialPeriodIndex: this.periodIndex(),
          initialGoalIndex: this.draft.period === 'TOTAL' ? 1 : 0,
          initialTarget: this.draft.targetCount.toString(), initialWeekdaysMask: this.draft.weekdaysMask,
          initialReminderTime: this.draft.reminderTime, initialAiInputText: this.input })
      } else {
        AddTaskSheet({ onDone: this.onDone, allowQuickAdd: false,
          initialName: this.draft.title || this.input, initialNote: this.draft.note,
          initialDueTime: this.draft.dueAt, initialAiInputText: this.input })
      }
    } else {
      Column({ space: 20 }) {
        Text('快速添加').fontSize(24).fontWeight(FontWeight.Bold)
        TextInput({ text: this.input, placeholder: '明天下午3点交报告 / 每天读书' })
          .enabled(!this.saving)
          .onChange((value: string) => { this.updateInput(value); })
        Text(modelDownloadLabel(this.modelStatus)).fontSize(14).width('100%').textAlign(TextAlign.Start)
        if (this.modelStatus.phase === 'DOWNLOADING') {
          Progress({ value: this.modelStatus.totalBytes > 0 ? this.modelStatus.downloadedBytes * 100 / this.modelStatus.totalBytes : 0,
            total: 100, type: ProgressType.Linear }).width('100%')
        }
        if (this.modelStatus.phase === 'FAILED' || this.modelStatus.phase === 'CANCELLED') {
          Button('重试下载模型').onClick(() => { void this.prepareModel(); })
        }
        if (this.draft.title.length > 0) {
          Text(this.draft.source === 'MODEL' ? '端侧模型识别' : this.draft.source === 'AI' ? 'AI 识别' : '规则识别')
            .fontSize(14).width('100%').textAlign(TextAlign.Start)
          Text((this.draft.kind === 'HABIT' ? '习惯：' : '任务：') + this.draft.title)
            .fontSize(20).width('100%').textAlign(TextAlign.Start)
          Text(QuickAddModels.detail(this.draft)).width('100%').textAlign(TextAlign.Start)
          if (this.draft.note.length > 0) { Text(this.draft.note).width('100%') }
        }
        if (this.loading) { Text('正在识别…') }
        if (this.message.length > 0) { Text(this.message).fontSize(14) }
        Button('使用 AI 识别').enabled(this.input.length > 0 && !this.loading && !this.saving)
          .onClick(() => { this.recognizeWithAI(); })
        Button(this.saving ? '保存中…' : '添加')
          .enabled(this.draft.ready && !this.loading && !this.saving)
          .onClick(() => { void this.save(); })
        Button('展开完整表单').enabled(!this.saving)
          .onClick(() => { this.invalidate(); this.loading = false; this.expanded = true; })
        Button('取消').enabled(!this.saving).onClick(this.onDone)
        Blank()
      }.width('100%').height('100%').padding(24)
    }
  }
}
