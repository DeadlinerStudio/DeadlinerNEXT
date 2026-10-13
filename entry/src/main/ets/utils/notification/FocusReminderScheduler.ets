import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { FocusTimerSnapshotPayload } from '../../model/FocusModels';

/** ReminderAgent returns a real reminder ID; notificationId is not a cancel handle. */
export class FocusReminderScheduler {
  private static activeSessionUid: string = '';
  private static activeReminderId: number = -1;
  private static restored: boolean = false;
  private static queue: Promise<void> = Promise.resolve();
  public static sync(timer: FocusTimerSnapshotPayload | null): Promise<void> {
    const next: Promise<void> = FocusReminderScheduler.queue.catch(() => {}).then(() => FocusReminderScheduler.syncNow(timer));
    FocusReminderScheduler.queue = next;
    return next;
  }
  private static async syncNow(timer: FocusTimerSnapshotPayload | null): Promise<void> {
    if (!FocusReminderScheduler.restored) {
      const valid: reminderAgentManager.ReminderInfo[] = await reminderAgentManager.getAllValidReminders();
      for (const info of valid) {
        const id: number = info.reminderReq.notificationId ?? -1;
        if (id >= 1200000 && id < 1900000) await FocusReminderScheduler.cancel(info.reminderId);
      }
      FocusReminderScheduler.restored = true;
    }
    if (timer === null || timer.mode !== 'COUNTDOWN' || timer.state !== 'RUNNING' ||
      timer.remainingSeconds === null || timer.remainingSeconds <= 0) {
      await FocusReminderScheduler.cancelActive(); return;
    }
    if (FocusReminderScheduler.activeSessionUid === timer.sessionUid && FocusReminderScheduler.activeReminderId >= 0) return;
    await FocusReminderScheduler.cancelActive();
    const request: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: Math.max(1, timer.remainingSeconds),
      title: '专注倒计时结束', content: '「' + timer.taskTitle + '」本轮专注已经完成。',
      notificationId: FocusReminderScheduler.identifier(timer.sessionUid),
      wantAgent: { pkgName: 'com.aritxonly.deadliner', abilityName: 'EntryAbility', uri: 'deadliner://focus/' + timer.sessionUid },
      actionButton: [{ title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }],
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION, ringDuration: 0
    };
    const reminderId: number = await reminderAgentManager.publishReminder(request);
    AppStorage.setOrCreate('FocusReminderWarning', '');
    FocusReminderScheduler.activeSessionUid = timer.sessionUid;
    FocusReminderScheduler.activeReminderId = reminderId;
  }
  private static cancel(id: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      reminderAgentManager.cancelReminder(id, (error: BusinessError) => {
        if (error === undefined || error.code === 1700003) resolve();
        else reject(error);
      });
    });
  }
  private static async cancelActive(): Promise<void> {
    if (FocusReminderScheduler.activeReminderId >= 0) await FocusReminderScheduler.cancel(FocusReminderScheduler.activeReminderId);
    FocusReminderScheduler.activeSessionUid = ''; FocusReminderScheduler.activeReminderId = -1;
  }
  private static identifier(value: string): number {
    let hash: number = 17;
    for (let i: number = 0; i < value.length; i++) hash = (hash * 31 + value.charCodeAt(i)) & 0x7fffffff;
    return 1200000 + hash % 700000;
  }
}
