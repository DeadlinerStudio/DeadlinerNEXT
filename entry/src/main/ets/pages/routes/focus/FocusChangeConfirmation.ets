import { KmpFocusTimerRepository, FocusCommandPayload } from '../../../common/kmp/KmpFocusTimerRepository';
import { FocusTimerUiStatePayload } from '../../../model/FocusModels';
import { FocusPresentation } from './FocusPresentation';
import { Toast } from '../../../common/ui/Toast';
import { UIContext } from '@kit.ArkUI';

class FocusChangeRequest {
  readonly uid: string;
  readonly habit: boolean;
  readonly deleting: boolean;
  readonly action: string;
  readonly sessionUid: string;
  readonly complete: (applied: boolean) => void;
  constructor(uid: string, habit: boolean, deleting: boolean, action: string,
    sessionUid: string, complete: (applied: boolean) => void) {
    this.uid = uid; this.habit = habit; this.deleting = deleting; this.action = action;
    this.sessionUid = sessionUid; this.complete = complete;
  }
  operation(): string {
    if (this.deleting) return '删除';
    if (this.habit || this.action === 'MARK_ARCHIVE') return '归档';
    return this.action === 'MARK_GIVE_UP' ? '放弃任务' : '完成任务';
  }
}

/** Repositories wait for explicit human confirmation, rendered by the root UIContext. */
export class FocusChangeConfirmation {
  private static pending: FocusChangeRequest | null = null;
  private static showing: boolean = false;
  private static applying: boolean = false;
  static async request(uid: string, habit: boolean, deleting: boolean, action: string = ''): Promise<boolean> {
    if (FocusChangeConfirmation.pending !== null) return false;
    const state: FocusTimerUiStatePayload = await KmpFocusTimerRepository.getInstance().state();
    const timer = state.timer;
    if (timer === null || (timer.target?.uid ?? timer.taskUid) !== uid || FocusChangeConfirmation.pending !== null) return false;
    return new Promise<boolean>((resolve) => {
      FocusChangeConfirmation.pending = new FocusChangeRequest(uid, habit, deleting, action, timer.sessionUid, resolve);
      AppStorage.setOrCreate('FocusConfirmationRevision', (AppStorage.get<number>('FocusConfirmationRevision') ?? 0) + 1);
    });
  }
  static present(context: UIContext): void {
    const request: FocusChangeRequest | null = FocusChangeConfirmation.pending;
    if (request === null || FocusChangeConfirmation.showing) return;
    FocusChangeConfirmation.showing = true;
    context.showAlertDialog({ title: '结束计时并' + request.operation() + '？',
      message: '将保存本轮有效专注时间，再执行原操作。不会自动打卡；不足一秒不生成记录。',
      primaryButton: { value: '取消', action: (): void => { FocusChangeConfirmation.cancel(); } },
      secondaryButton: { value: '结束计时并' + request.operation(), action: (): void => { FocusChangeConfirmation.apply(request); } },
      cancel: (): void => { FocusChangeConfirmation.cancel(); }
    });
  }
  static cancel(): void {
    if (FocusChangeConfirmation.applying) return;
    const request: FocusChangeRequest | null = FocusChangeConfirmation.pending;
    FocusChangeConfirmation.pending = null;
    FocusChangeConfirmation.showing = false;
    request?.complete(false);
  }
  private static async apply(request: FocusChangeRequest): Promise<void> {
    if (FocusChangeConfirmation.applying || FocusChangeConfirmation.pending !== request) return;
    FocusChangeConfirmation.applying = true;
    const command: FocusCommandPayload = { operation: request.habit ? (request.deleting ? 'resolve_habit_delete' : 'resolve_habit_archive') :
      (request.deleting ? 'resolve_task_delete' : 'resolve_task_action'), sessionUid: request.sessionUid, taskAction: request.action };
    if (request.habit) command.habitUid = request.uid;
    else command.taskUid = request.uid;
    let applied: boolean = false;
    try {
      const state: FocusTimerUiStatePayload = await KmpFocusTimerRepository.getInstance().execute(command);
      applied = state.error === null && (state.lastOutcome === 'APPLIED' || state.lastOutcome === 'NO_OP');
      if (!applied) Toast.show({ message: state.error ?? FocusPresentation.outcome(state.lastOutcome ?? 'INVALID_STATE') });
    } catch (_error) { Toast.show({ message: '操作未完成，计时和目标保持原状，请重试。' }); }
    FocusChangeConfirmation.pending = null;
    FocusChangeConfirmation.showing = false;
    FocusChangeConfirmation.applying = false;
    request.complete(applied);
  }
}
