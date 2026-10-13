import { KmpPersistenceService } from './KmpPersistenceService';
import { FocusReminderScheduler } from '../../utils/notification/FocusReminderScheduler';
import { FocusTimerUiStatePayload } from '../../model/FocusModels';
import { AppLog } from '../logging/AppLog';

export interface FocusCommandPayload {
  operation: string;
  taskUid?: string;
  habitUid?: string;
  targetKind?: string;
  targetUid?: string;
  durationSeconds?: number;
  sessionUid?: string;
  taskAction?: string;
  amount?: number;
  expectedHabitUpdatedAt?: string;
}
interface FocusTargetQuery { targetKind: string; targetUid: string; }

export class KmpFocusTimerRepository {
  private static instance: KmpFocusTimerRepository;
  private readonly persistence: KmpPersistenceService = KmpPersistenceService.getInstance();
  public static getInstance(): KmpFocusTimerRepository {
    if (!KmpFocusTimerRepository.instance) KmpFocusTimerRepository.instance = new KmpFocusTimerRepository();
    return KmpFocusTimerRepository.instance;
  }
  public async state(uid: string = '', kind: string = 'TASK'): Promise<FocusTimerUiStatePayload> {
    const query: FocusTargetQuery = { targetKind: kind, targetUid: uid };
    const raw: string = uid.length === 0 ? this.persistence.focusStateJson('') :
      this.persistence.focusTargetStateJson(JSON.stringify(query));
    const state: FocusTimerUiStatePayload = JSON.parse(raw);
    await this.syncReminder(state);
    return state;
  }
  /** Stateless native bridge: preserve an explicitly selected historical session on every refresh.
   * Selection reads do not publish revision events (avoids Watch -> query -> Watch loops). */
  public async sessionState(sessionUid: string): Promise<FocusTimerUiStatePayload> {
    const query: FocusCommandPayload = { operation: 'select_session', sessionUid: sessionUid };
    const state: FocusTimerUiStatePayload = JSON.parse(this.persistence.focusCommandJson(JSON.stringify(query)));
    await this.syncReminder(state);
    if (state.timer === null && state.lastCompletedSession?.uid !== sessionUid) {
      state.lastCompletedSession = null;
      state.habitRecordContext = null;
      state.selectedTarget = null;
      state.selectedTaskUid = null;
      state.selectedTaskTitle = null;
      state.selectedTaskRecentSessions = [];
      state.selectedTaskTodayDurationSeconds = 0;
      state.selectedTaskTotalDurationSeconds = 0;
      state.error = '该专注记录已删除或不可用。';
    }
    return state;
  }
  public async execute(request: FocusCommandPayload): Promise<FocusTimerUiStatePayload> {
    const state: FocusTimerUiStatePayload = JSON.parse(this.persistence.focusCommandJson(JSON.stringify(request)));
    await this.syncReminder(state);
    if (state.lastOutcome === 'APPLIED' && request.operation !== 'select_session') {
      AppStorage.setOrCreate('KmpDataRevision', (AppStorage.get<number>('KmpDataRevision') ?? 0) + 1);
    }
    AppStorage.setOrCreate('FocusTimerActive', state.timer !== null);
    AppStorage.setOrCreate('FocusTimerRevision', (AppStorage.get<number>('FocusTimerRevision') ?? 0) + 1);
    return state;
  }
  public async command(operation: string, taskUid: string = '', durationSeconds: number = 0,
    sessionUid: string = '', taskAction: string = ''): Promise<FocusTimerUiStatePayload> {
    const request: FocusCommandPayload = { operation: operation };
    if (taskUid.length > 0) request.taskUid = taskUid;
    if (durationSeconds > 0) request.durationSeconds = durationSeconds;
    if (sessionUid.length > 0) request.sessionUid = sessionUid;
    if (taskAction.length > 0) request.taskAction = taskAction;
    return this.execute(request);
  }
  private async syncReminder(state: FocusTimerUiStatePayload): Promise<void> {
    try { await FocusReminderScheduler.sync(state.timer); }
    catch (_error) {
      AppStorage.setOrCreate('FocusReminderWarning', '系统提醒不可用；计时已保存，请检查通知和提醒权限。');
      AppLog.warn('Native', 'Focus reminder unavailable; timer remains saved');
    }
  }
}
