import { FocusTextAction } from './FocusTimerControls';
import { FocusActiveContent } from './FocusActiveContent';
import { FocusActiveUiState, FocusRequestGate } from './FocusUiState';
import { FocusSummaryContent, FocusResultContent, FocusRecordConfirmation, FocusHistoryRow, FocusTargetPicker } from './FocusDetailComponents';
import { FocusTimerSetup } from './FocusTimerSetup';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { FocusCommandPayload } from '../../../common/kmp/KmpFocusTimerRepository';
import { DDLItem, Habit, HabitStatus } from '../../../model/DDLModels';
import { TaskState } from '../../../model/TaskStateMachine';
import {
  FocusSessionPayload,
  FocusHabitRecordContextPayload,
  FocusTimerSnapshotPayload,
  FocusTimerUiStatePayload
} from '../../../model/FocusModels';
import { KmpFocusTimerRepository } from '../../../common/kmp/KmpFocusTimerRepository';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { FocusPresentation } from './FocusPresentation';
import { Toast } from '../../../common/ui/Toast';
import { getImmersiveTitleBarStyle } from '../../../common/style/NavStyles';

@Component
export struct FocusTimerSheet {
  @Link @Watch('onVisibilityChanged') isShow: boolean;
  @Prop initialTask: DDLItem | null = null;
  @Prop initialHabit: Habit | null = null;
  @Prop @Watch('onInitialSessionChanged') initialSessionUid: string = '';
  @State private selectedSessionUid: string = '';
  private onInitialSessionChanged(): void {
    if (this.initialSessionUid.length > 0 && this.isShow) { this.selectedSessionUid = this.initialSessionUid; this.refreshState(); }
  }

  @StorageLink('FocusTimerRevision') @Watch('onExternalFocusChanged') focusRevision: number = 0;
  private onExternalFocusChanged(): void { if (!this.isBusy && this.isShow) this.refreshState(); }
  @State private state: FocusTimerUiStatePayload | null = null;
  @State private timerUi: FocusActiveUiState = new FocusActiveUiState(null);
  private applyState(next: FocusTimerUiStatePayload): void {
    this.state = next;
    this.timerUi = new FocusActiveUiState(next.timer);
    this.displaySeconds = this.resolveDisplaySeconds(next.timer);
    if (next.timer !== null) this.enteredTimer = true;
  }
  private toggleCurrentTimer(): void {
    const timer: FocusTimerSnapshotPayload | null = this.state?.timer ?? null;
    if (timer === null || this.isBusy) return;
    if (timer.canPause) this.runCommand('pause');
    else if (timer.canResume) this.runCommand('resume');
  }
  private jointFinishCurrentTimer(): void {
    const timer: FocusTimerSnapshotPayload | null = this.state?.timer ?? null;
    if (timer === null || this.isBusy) return;
    if (timer.target?.kind === 'HABIT') this.beginRecord(timer);
    else if (timer.canFinishAndComplete) this.runCommand('finish_and_complete');
  }
  @State private activeTasks: DDLItem[] = [];
  @State private activeHabits: Habit[] = [];
  @State private selectedKind: string = 'TASK';
  @State private recordingSessionUid: string = '';
  @State private amountText: string = '';
  @State private recordContext: FocusHabitRecordContextPayload | null = null;
  private expectedHabitUpdatedAt: string = '';
  private readonly habitRepository: HabitRepository = HabitRepository.getInstance();
  @State private selectedTaskUid: string = '';
  @State private selectedTaskTitle: string = '';
  @State private countdownMinutes: number = 25;
  @State private enteredTimer: boolean = false;
  @State private selectingTarget: boolean = false;
  @State private displaySeconds: number = 0;
  @State private editingSessionUid: string = '';
  @State private editDurationText: string = '';
  @State private isBusy: boolean = false;

  private readonly requestGate: FocusRequestGate = new FocusRequestGate();
  private timerId: number = -1;
  private tickCount: number = 0;
  private readonly repository: KmpFocusTimerRepository = KmpFocusTimerRepository.getInstance();
  private readonly taskRepository: TaskRepository = TaskRepository.getInstance();

  aboutToAppear(): void {
    this.applyInitialTask();
    this.load();
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private onVisibilityChanged(): void {
    if (this.isShow) {
      this.applyInitialTask();
      this.load();
      this.startTicker();
    } else {
      this.stopTicker();
    }
  }

  private applyInitialTask(): void {
    this.enteredTimer = this.initialTask === null && this.initialHabit === null;
    this.selectingTarget = false;
    if (this.initialHabit !== null && this.initialHabit.uid !== undefined) {
      this.selectedTaskUid = this.initialHabit.uid;
      this.selectedTaskTitle = this.initialHabit.name;
      this.selectedKind = 'HABIT';
      return;
    }
    if (this.initialTask !== null && this.initialTask.uid !== undefined) {
      this.selectedKind = 'TASK';
      this.selectedTaskUid = this.initialTask.uid;
      this.selectedTaskTitle = this.initialTask.name;
    }
  }

  private startTicker(): void {
    if (this.timerId >= 0) return;
    this.timerId = setInterval(() => {
      const timer: FocusTimerSnapshotPayload | null = this.state === null ? null : this.state.timer;
      if (timer === null || timer.state !== 'RUNNING') return;
      this.displaySeconds = timer.mode === 'COUNTDOWN' ? Math.max(0, this.displaySeconds - 1) : this.displaySeconds + 1;
      this.tickCount += 1;
      if (timer.mode === 'COUNTDOWN' && this.displaySeconds === 0) {
        this.runCommand('reconcile');
      } else if (this.tickCount % 15 === 0) {
        this.refreshState();
      }
    }, 1000);
  }

  private stopTicker(): void {
    this.requestGate.begin();
    if (this.timerId >= 0) clearInterval(this.timerId);
    this.timerId = -1;
  }

  private async load(): Promise<void> {
    try {
      const tasks: DDLItem[] = await this.taskRepository.getAllDDLs();
      this.activeTasks = tasks.filter((item: DDLItem): boolean => item.state === TaskState.ACTIVE && !item.deleted);
      this.activeHabits = (await this.habitRepository.getAllHabits()).filter((item: Habit) => item.status === HabitStatus.ACTIVE);
      if (this.initialSessionUid.length > 0) this.selectedSessionUid = this.initialSessionUid;
      await this.refreshState();
    } catch (_error) {
      Toast.show({ message: '加载专注计时失败' });
    }
  }

  private async refreshState(): Promise<void> {
    if (this.isBusy) return;
    const requestId: number = this.requestGate.begin();
    try {
      const next: FocusTimerUiStatePayload = this.selectedSessionUid.length > 0 ? await this.repository.sessionState(this.selectedSessionUid) :
        await this.repository.state(this.selectedTaskUid, this.selectedKind);
      if (!this.requestGate.accepts(requestId)) return;
      this.applyState(next);
      if (next.timer !== null) { this.selectedSessionUid = ''; this.enteredTimer = true; }
      else if (next.selectedTarget !== null) {
        this.selectedTaskUid = next.selectedTarget.uid;
        this.selectedKind = next.selectedTarget.kind;
        this.selectedTaskTitle = next.selectedTaskTitle ??
          next.lastCompletedSession?.taskTitleSnapshot ?? this.selectedTaskTitle;
      }
      if (next.timer !== null) {
        this.selectedTaskUid = next.timer.target?.uid ?? next.timer.taskUid;
        this.selectedKind = next.timer.target?.kind ?? 'TASK';
        this.selectedTaskTitle = next.timer.taskTitle;
      } else if (next.selectedTaskUid !== null) {
        this.selectedTaskUid = next.selectedTaskUid;
        this.selectedTaskTitle = next.selectedTaskTitle ?? this.selectedTaskTitle;
      }
      this.displaySeconds = this.resolveDisplaySeconds(next.timer);
    } catch (_error) {
      Toast.show({ message: '刷新专注计时失败' });
    }
  }

  private selectTask(task: DDLItem): void {
    this.selectedSessionUid = '';
    this.selectingTarget = false;
    this.selectedKind = 'TASK';
    this.selectedTaskUid = task.uid ?? '';
    this.selectedTaskTitle = task.name;
    this.refreshState();
  }

  private selectHabit(habit: Habit): void {
    this.selectedSessionUid = '';
    this.selectingTarget = false;
    this.selectedKind = 'HABIT';
    this.selectedTaskUid = habit.uid ?? '';
    this.selectedTaskTitle = habit.name;
    this.refreshState();
  }

  private beginRecord(timer: FocusTimerSnapshotPayload): void {
    if (!timer.canFinishAndRecord || timer.habitRecordContext === null) return;
    this.recordingSessionUid = timer.sessionUid;
    this.recordContext = timer.habitRecordContext;
    this.expectedHabitUpdatedAt = timer.habitRecordContext.habitUpdatedAt;
    this.amountText = '';
  }

  private recordMetadataChanged(): boolean {
    const fresh: FocusHabitRecordContextPayload | null = this.state?.habitRecordContext ?? null;
    return this.recordContext !== null && fresh !== null && fresh.habitUid === this.recordContext.habitUid &&
      fresh.occurredOn === this.recordContext.occurredOn && fresh.habitUpdatedAt !== this.expectedHabitUpdatedAt;
  }
  private beginSavedRecord(session: FocusSessionPayload): void {
    if (this.isBusy || this.state?.timer !== null) {
      Toast.show({ message: '请先结束当前专注，再为历史记录打卡。' }); return;
    }
    this.isBusy = true;
    const requestId: number = this.requestGate.begin();
    this.repository.sessionState(session.uid).then((state: FocusTimerUiStatePayload) => {
      if (!this.requestGate.accepts(requestId)) return;
      const context: FocusHabitRecordContextPayload | null = state.habitRecordContext;
      if (state.timer !== null || context === null || context.habitUid !== session.target?.uid || context.occurredOn !== session.habitOccurredOn || !context.canRecord) {
        Toast.show({ message: '该记录当前不可打卡；不影响已保存时长' }); return;
      }
      this.applyState(state);
      this.selectedSessionUid = session.uid;
      this.recordingSessionUid = session.uid;
      this.recordContext = context;
      this.expectedHabitUpdatedAt = context.habitUpdatedAt;
      this.amountText = '';
    }).catch(() => { Toast.show({ message: '读取打卡信息失败' }); }).finally(() => { this.isBusy = false; });
  }

  private confirmRecord(): void {
    if (this.isBusy || this.recordMetadataChanged() || this.recordContext === null || this.recordingSessionUid.length === 0) return;
    const quantity: boolean = this.recordContext.trackingMode === 'QUANTITY';
    if (quantity && (!/^[1-9][0-9]*$/.test(this.amountText) || Number(this.amountText) > 2147483647)) {
      Toast.show({ message: '请输入本次实际完成的正整数数量' }); return;
    }
    this.runCommand('finish_and_record_habit', quantity ? Number(this.amountText) : 0, this.recordingSessionUid);
  }

  private async runCommand(operation: string, durationSeconds: number = 0, sessionUid: string = ''): Promise<void> {
    if (this.isBusy) return;
    this.isBusy = true;
    const requestId: number = this.requestGate.begin();
    try {
      const request: FocusCommandPayload = { operation: operation, targetKind: this.selectedKind, targetUid: this.selectedTaskUid };
      if (this.selectedKind === 'HABIT') request.habitUid = this.selectedTaskUid;
      else request.taskUid = this.selectedTaskUid;
      if (this.selectedKind === 'HABIT' && operation === 'start_stopwatch') request.operation = 'start_habit_stopwatch';
      if (this.selectedKind === 'HABIT' && operation === 'start_countdown') request.operation = 'start_habit_countdown';
      if (durationSeconds > 0) request.durationSeconds = durationSeconds;
      if (sessionUid.length > 0) request.sessionUid = sessionUid;
      if (operation === 'finish_and_record_habit') {
        if (durationSeconds > 0) request.amount = durationSeconds;
        request.expectedHabitUpdatedAt = this.expectedHabitUpdatedAt;
      }
      const next: FocusTimerUiStatePayload = await this.repository.execute(request);
      if (!this.requestGate.accepts(requestId)) return;
      this.applyState(next);
      if (next.timer !== null) this.selectedSessionUid = '';
      else if (next.lastCompletedSession !== null) this.selectedSessionUid = next.lastCompletedSession.uid;
      if (next.error !== null) Toast.show({ message: next.error });
      if (next.lastOutcome === 'APPLIED' || next.lastOutcome === 'NO_OP') {
        if (operation === 'finish_and_record_habit') { this.recordingSessionUid = ''; this.recordContext = null; }
        getContext(this).eventHub.emit('sync_done');
      }
      if (next.timer !== null) {
        this.selectedTaskUid = next.timer.target?.uid ?? next.timer.taskUid;
        this.selectedKind = next.timer.target?.kind ?? 'TASK';
        this.selectedTaskTitle = next.timer.taskTitle;
      }
      this.displaySeconds = this.resolveDisplaySeconds(next.timer);
      this.tickCount = 0;
      if (next.timer === null) AppStorage.setOrCreate('FocusResolutionMessage', '');
    } catch (_error) {
      Toast.show({ message: '专注计时操作失败' });
    } finally {
      this.isBusy = false;
    }
  }

  private resolveDisplaySeconds(timer: FocusTimerSnapshotPayload | null): number {
    if (timer === null) return 0;
    return timer.remainingSeconds === null ? timer.elapsedSeconds : timer.remainingSeconds;
  }

  private beginEdit(session: FocusSessionPayload): void {
    this.editingSessionUid = session.uid;
    this.editDurationText = session.durationSeconds.toString();
  }

  private saveEdit(session: FocusSessionPayload): void {
    const duration: number = parseInt(this.editDurationText);
    if (!Number.isInteger(duration) || duration < 1 || duration > Math.min(86400, Math.floor((Date.parse(session.endedAt) - Date.parse(session.startedAt)) / 1000))) {
      Toast.show({ message: '更正时长需在 1 秒与真实跨度之间，最多 24 小时' });
      return;
    }
    this.editingSessionUid = '';
    this.runCommand('adjust_session', duration, session.uid);
  }

  private confirmDelete(session: FocusSessionPayload): void {
    this.getUIContext().showAlertDialog({
      title: '删除专注记录？',
      message: '删除后从专注统计中扣除，不撤销任务完成或习惯打卡。',
      primaryButton: {
        value: '删除',
        action: () => this.runCommand('delete_session', 0, session.uid)
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private confirmDiscard(): void {
    this.getUIContext().showAlertDialog({
      title: '放弃本轮计时？', message: '本轮时间不会保存。',
      primaryButton: { value: '放弃', action: (): void => { this.runCommand('discard'); } },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: 24 }) {
          if (this.state === null) {
            LoadingProgress().width(42).height(42).margin({ top: 120 })
          } else {
            if ((AppStorage.get<string>('FocusResolutionMessage') ?? '').length > 0 && this.state.timer !== null) {
              Text(AppStorage.get<string>('FocusResolutionMessage') ?? '').fontSize(13).width('100%')
            }
            if ((AppStorage.get<string>('FocusReminderWarning') ?? '').length > 0) {
              Text(AppStorage.get<string>('FocusReminderWarning') ?? '').fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            if (this.timerUi.hasTimer) {
              if (this.state.warning !== null) {
                Text(FocusPresentation.warning(this.state.warning)).fontSize(14).width('100%')
                  .padding(16).backgroundColor($r('app.color.background_secondary')).borderRadius(20)
                  .fontColor($r('sys.color.font_primary'))
              }
              FocusActiveContent({ title: this.timerUi.title, habitDate: this.timerUi.habitDate, seconds: this.displaySeconds,
                countdown: this.timerUi.countdown, plannedSeconds: this.timerUi.plannedSeconds, paused: this.timerUi.paused,
                canPause: this.timerUi.canPause, canResume: this.timerUi.canResume, canFinish: this.timerUi.canFinish,
                canJointFinish: this.timerUi.canJointFinish, isHabit: this.timerUi.isHabit, busy: this.isBusy,
                onFinish: (): void => { this.runCommand('finish'); }, onToggle: (): void => { this.toggleCurrentTimer(); },
                onJointFinish: (): void => { this.jointFinishCurrentTimer(); }, onDiscard: (): void => { this.confirmDiscard(); } })
            } else if (!this.enteredTimer) {
              if (this.selectingTarget) {
                FocusTargetPicker({ tasks: this.activeTasks, habits: this.activeHabits, busy: this.isBusy,
                  onTask: (task: DDLItem): void => { this.selectTask(task); }, onHabit: (habit: Habit): void => { this.selectHabit(habit); },
                  onCancel: (): void => { this.selectingTarget = false; } })
              }
              else {
                FocusTimerSetup({ title: this.selectedTaskTitle, busy: this.isBusy, available: this.selectedTaskUid.length > 0,
                  minutes: $countdownMinutes, onChooseTarget: (): void => { this.selectingTarget = true; },
                  onStart: (countdown: boolean): void => { this.runCommand(countdown ? 'start_countdown' : 'start_stopwatch', countdown ? Math.round(this.countdownMinutes) * 60 : 0); } })
              }
            } else {
              FocusResultContent({ hasSession: this.state.lastCompletedSession !== null,
                seconds: this.state.lastCompletedSession?.durationSeconds ?? 0,
                showRecord: this.state.lastCompletedSession?.target?.kind === 'HABIT' &&
                  (this.state.lastCompletedSession?.habitRecordedAmount === null || this.state.lastCompletedSession?.habitRecordedAmount === undefined) && this.recordingSessionUid.length === 0,
                canRecord: this.state.habitRecordContext?.canRecord === true, busy: this.isBusy,
                canCompleteTask: this.state.canCompleteLastTask === true,
                taskCompleted: this.state.lastCompletedTaskState === TaskState.COMPLETED || this.state.lastCompletedTaskState === TaskState.ARCHIVED,
                onCompleteTask: (): void => { if (this.state?.lastCompletedSession) this.runCommand('complete_saved_task', 0, this.state.lastCompletedSession.uid); },
                onRecord: (): void => { if (this.state?.lastCompletedSession) this.beginSavedRecord(this.state.lastCompletedSession); } })
            }
            if (this.state.lastOutcome !== null && this.state.lastOutcome !== 'APPLIED' && this.state.lastOutcome !== 'NO_OP') {
              Text(FocusPresentation.outcome(this.state.lastOutcome)).fontSize(13).fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            if (this.state.error !== null) Text(this.state.error).fontSize(13).fontColor($r('sys.color.ohos_id_color_text_secondary'))
            if (this.state.warning !== null && !this.timerUi.hasTimer) Text(FocusPresentation.warning(this.state.warning)).fontSize(14)
            if (this.recordingSessionUid.length > 0 && this.recordContext !== null) {
              FocusRecordConfirmation({ name: this.recordContext.name, date: this.recordContext.occurredOn,
                quantity: this.recordContext.trackingMode === 'QUANTITY', unit: this.recordContext.unit ?? '',
                metadataChanged: this.recordMetadataChanged(), busy: this.isBusy, amount: $amountText,
                onCancel: (): void => { this.recordingSessionUid = ''; this.recordContext = null; },
                onConfirm: (): void => { this.confirmRecord(); } })
            }
            if (this.enteredTimer) {
              FocusSummaryContent({ title: this.selectedTaskTitle, selected: this.selectedTaskUid.length > 0,
                todaySeconds: this.selectedTaskUid.length > 0 ? this.state.selectedTaskTodayDurationSeconds : this.state.todayDurationSeconds,
                totalSeconds: this.state.selectedTaskTotalDurationSeconds, sessionCount: this.state.todaySessionCount })
              Text('最近记录').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
              if ((this.selectedTaskUid.length > 0 ? this.state.selectedTaskRecentSessions : this.state.recentSessions).length === 0) {
                Text('还没有专注记录').fontColor($r('sys.color.font_secondary')).width('100%')
              } else {
                ForEach((this.selectedTaskUid.length > 0 ? this.state.selectedTaskRecentSessions : this.state.recentSessions).slice(0, 5), (session: FocusSessionPayload) => {
                  FocusHistoryRow({ startedAt: session.startedAt, seconds: session.durationSeconds,
                    showRecord: session.target?.kind === 'HABIT' && (session.habitRecordedAmount === null || session.habitRecordedAmount === undefined),
                    canRecord: !this.timerUi.hasTimer, editing: this.editingSessionUid === session.uid, editText: $editDurationText,
                    busy: this.isBusy, onRecord: (): void => { this.beginSavedRecord(session); },
                    onEdit: (): void => { this.beginEdit(session); }, onDelete: (): void => { this.confirmDelete(session); },
                    onSave: (): void => { this.saveEdit(session); }, onCancelEdit: (): void => { this.editingSessionUid = ''; } })
                }, (session: FocusSessionPayload) => session.uid + '_' + session.updatedAt)
              }
            }
          }
          FocusTextAction({ label: '返回清单', actionEnabled: !this.isBusy, onAction: (): void => { this.isShow = false; } })
          Blank().height(24)
        }
        .width('100%')
        .padding({ top: 64, left: 16, right: 16 }).justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off).align(Alignment.Top)
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: {
        title: { mainTitle: this.enteredTimer ? '专注' : '开始专注' }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height('100%')
  }
}
