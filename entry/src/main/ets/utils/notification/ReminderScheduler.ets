import { AppLog } from '../../common/logging/AppLog';
import { ReminderDataManager } from './ReminderDataManager';
import { ActiveReminder } from '../../model/ActiveReminder';
import { DateTimeUtils } from '../../utils/DateTimeUtils';
import { DDLItem, Habit } from '../../model/DDLModels';
import { HabitReminderPlan } from '../../common/kmp/KmpHabitRepositoryAdapter';
import { ReminderUtils } from './ReminderUtils';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { LocalValues } from '../../common/local/LocalValues';
import { TaskState } from '../../model/TaskStateMachine';

const MAX_DDL_SLOTS = 20;
const MAX_HABIT_SLOTS = 20;

interface DDLReminderCandidate {
  item: DDLItem;
}

interface HabitReminderCandidate {
  habit: Habit;
  targetId: string;
  fireAt: Date;
}

export function collectDDLReminderCancelIds(taskId: number, reminderId?: number): number[] {
  const ids = new Set<number>([taskId]);
  if (reminderId !== undefined) {
    ids.add(reminderId);
  }
  return Array.from(ids);
}

export class ReminderScheduler {
  private static ddlRefreshQueue: Promise<void> = Promise.resolve();

  static shouldScheduleDDLReminder(item: DDLItem): boolean {
    return !item.deleted && item.state === TaskState.ACTIVE;
  }

  /**
   * 核心方法：清洗“僵尸”数据
   * * 场景：用户卸载重装（保留数据）或系统清理了过期任务，导致 DB 有记录但系统无任务。
   * 作用：强制对账。如果 DB 里有，但系统里没有，则删除 DB 记录，迫使后续逻辑重新发布。
   */
  private static async syncWithSystem(activeReminders: ActiveReminder[]): Promise<string[]> {
    if (activeReminders.length === 0) return [];

    try {
      const systemReminders = await reminderAgentManager.getValidReminders();
      if (systemReminders.length === 0 && activeReminders.length > 0) {
        // 如果系统返回空，但本地有记录，可能是接口延迟或权限问题，保守处理，暂不视为僵尸
        AppLog.warn('Native', `[Scheduler] System returned 0 reminders but local has ${activeReminders.length}. Skipping sync.`);
        return [];
      }

      const systemIds = new Set(systemReminders.map(r => r.notificationId));
      const zombieIds: string[] = [];

      for (const record of activeReminders) {
        if (!systemIds.has(record.reminderId)) {
          AppLog.warn('Native', `[Scheduler] Potential zombie found: ${record.targetId} (ID:${record.reminderId}).`);
          zombieIds.push(record.targetId);
        }
      }
      return zombieIds;
    } catch (e) {
      AppLog.error('Native', `[Scheduler] Sync failed: ${e}.`);
      return [];
    }
  }

  // =========================================================
  // 1. DDL 提醒 (单次 - 使用 Timer 伪装)
  // =========================================================
  static async refreshReminders(allDDLs: DDLItem[]) {
    const task = ReminderScheduler.ddlRefreshQueue
      .catch(() => {})
      .then(async () => {
        await ReminderScheduler.performDDLRefresh(allDDLs);
      });

    ReminderScheduler.ddlRefreshQueue = task.catch(() => {});
    return task;
  }

  static async cancelDDLReminder(taskId: number): Promise<void> {
    const targetId = taskId.toString();
    const manager = ReminderDataManager.getInstance();
    const existingRecord = manager.getByScopedTarget('DDL', targetId);
    const idsToCancel = collectDDLReminderCancelIds(taskId, existingRecord?.reminderId);

    for (const reminderId of idsToCancel) {
      await ReminderUtils.cancel(reminderId);
    }
    await manager.removeScoped('DDL', targetId);
  }

  private static async performDDLRefresh(allDDLs: DDLItem[]) {
    AppLog.info('Native', '[Scheduler] Start refreshing DDLs...');

    const isEnabled = LocalValues.getInstance().getDDLWarning();
    const manager = ReminderDataManager.getInstance();

    if (!isEnabled) {
      AppLog.info('Native', '[Scheduler] DDL Warning is DISABLED. Clearing existing reminders...');
      await ReminderScheduler.clearAllDDLReminders(manager.getAllByType('DDL'), []);
      return;
    }

    const now = Date.now();

    interface Candidate {
      item: DDLItem;
      date: Date | null;
      timestamp: number;
    }

    const candidates: Candidate[] = allDDLs
      .filter(item => ReminderScheduler.shouldScheduleDDLReminder(item))
      .map((item: DDLItem): Candidate => {
        const date = DateTimeUtils.parseDateString(item.endTime);
        return {
          item: item,
          date: date,
          timestamp: date ? date.getTime() : 0
        };
      })
      // 过滤掉已过期的任务 (注意：DDL 截止时间必须在未来)
      .filter(c => c.date !== null && c.timestamp > now)
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(0, MAX_DDL_SLOTS);

    await ReminderScheduler.clearAllDDLReminders(manager.getAllByType('DDL'), candidates);

    for (const c of candidates) {
      await ReminderScheduler.publishAndRecord(c.item, c.date!);
    }
  }

  // =========================================================
  // 2. 习惯打卡（KMP 权威具体日期，平台发布单次 Timer）
  // =========================================================
  static async refreshHabits(plans: HabitReminderPlan[]): Promise<void> {
    AppLog.info('Native', '[Scheduler] Start refreshing HABIT reminders...');

    const isEnabled = LocalValues.getInstance().getHabitReminder();
    const manager = ReminderDataManager.getInstance();

    const activeReminders: ActiveReminder[] = manager.getAllByType('HABIT');
    const zombieIds: string[] = await ReminderScheduler.syncWithSystem(activeReminders);

    const activeMap = new Map<string, ActiveReminder>();
    for (const record of activeReminders) {
      if (zombieIds.includes(record.targetId)) {
        await manager.removeScoped(record.type, record.targetId);
        continue;
      }
      activeMap.set(record.targetId, record);
    }

    if (!isEnabled) {
      if (activeReminders.length > 0) {
        AppLog.info('Native', '[Scheduler] Habit Reminder is DISABLED. Clearing existing reminders...');
        for (const record of activeReminders) {
          await ReminderScheduler.cancelAndRemove(record.type, record.targetId, record.reminderId, "Feature disabled");
        }
      }
      return;
    }

    const now: number = Date.now();
    const candidates: HabitReminderCandidate[] = [];
    for (let planIndex: number = 0; planIndex < plans.length; planIndex += 1) {
      const plan: HabitReminderPlan = plans[planIndex];
      for (let dateIndex: number = 0; dateIndex < plan.scheduledLocalDateTimes.length; dateIndex += 1) {
        const rawDate: string = plan.scheduledLocalDateTimes[dateIndex];
        const fireAt: Date = new Date(rawDate);
        if (isNaN(fireAt.getTime()) || fireAt.getTime() <= now) continue;
        candidates.push({
          habit: plan.habit,
          targetId: plan.habit.id.toString() + '|' + rawDate,
          fireAt: fireAt
        });
      }
    }
    candidates.sort((left: HabitReminderCandidate, right: HabitReminderCandidate) =>
      left.fireAt.getTime() - right.fireAt.getTime()
    );
    const boundedCandidates: HabitReminderCandidate[] = candidates.slice(0, MAX_HABIT_SLOTS);
    const candidateIds: Set<string> = new Set<string>();
    for (let index: number = 0; index < boundedCandidates.length; index += 1) {
      candidateIds.add(boundedCandidates[index].targetId);
    }

    // --- 阶段 A: 清理 ---
    for (const record of activeReminders) {
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.type, record.targetId, record.reminderId, 'Habit plan removed');
        activeMap.delete(record.targetId);
        continue;
      }
      let expectedTime: number = 0;
      for (let index: number = 0; index < boundedCandidates.length; index += 1) {
        if (boundedCandidates[index].targetId === record.targetId) {
          expectedTime = boundedCandidates[index].fireAt.getTime();
          break;
        }
      }
      if (expectedTime !== record.triggerTime) {
        await ReminderScheduler.cancelAndRemove(record.type, record.targetId, record.reminderId, 'Habit plan time changed');
        activeMap.delete(record.targetId);
      }
    }

    // --- 阶段 B: 发布 ---
    for (let index: number = 0; index < boundedCandidates.length; index += 1) {
      const candidate: HabitReminderCandidate = boundedCandidates[index];
      if (activeMap.has(candidate.targetId)) continue;
      await ReminderScheduler.publishHabit(candidate);
    }
  }

  // =========================================================
  // 3. 每日摘要 (循环 - 使用 Alarm)
  // =========================================================
  static async refreshDailySummary(summaryTimeStr: string | null) {
    const TARGET_ID = 'DAILY_SUMMARY';
    const manager = ReminderDataManager.getInstance();
    let existingRecord = manager.getByScopedTarget('SUMMARY', TARGET_ID);

    // 如果 summaryTimeStr 为 null，或者 LocalValues 里关闭了 (双重保障)
    // Settings 页面传参时已经处理了逻辑，传 null 即表示关闭
    if (!summaryTimeStr) {
      if (existingRecord) {
        await ReminderScheduler.cancelAndRemove('SUMMARY', TARGET_ID, existingRecord.reminderId, "Feature disabled / turned off");
      }
      return;
    }

    const parts = summaryTimeStr.split(':');
    const hour = parseInt(parts[0]);
    const minute = parseInt(parts[1]);

    // 检查是否需要更新
    if (existingRecord) {
      const recordDate = new Date(existingRecord.triggerTime);

      if (recordDate.getHours() === hour && recordDate.getMinutes() === minute) {
        AppLog.info('Native', '[Scheduler] Daily Summary time unchanged. Skip.');
        return;
      }
      await ReminderScheduler.cancelAndRemove('SUMMARY', TARGET_ID, existingRecord.reminderId, "Time update");
    }

    // 发布新提醒
    try {
      const daysOfWeek = [1, 2, 3, 4, 5, 6, 7]; // 每天

      AppLog.info('Native', `[Scheduler] Publishing Daily Summary at ${hour}:${minute}`);

      const reminderId = await ReminderUtils.publishAlarm(
        "每日摘要",
        "回顾今天，规划明天。点击查看今日概览。",
        hour,
        minute,
        daysOfWeek,
        100000 // 固定 ID
      );

      const recordTime = new Date();
      recordTime.setHours(hour, minute, 0, 0);

      const newRecord: ActiveReminder = {
        targetId: TARGET_ID,
        type: 'SUMMARY',
        reminderId: reminderId,
        triggerTime: recordTime.getTime()
      };
      await manager.addOrUpdate(newRecord);
    } catch (e) {
      AppLog.error('Native', `[Scheduler] Failed to publish summary: ${e}`);
    }
  }

  // ==========================================
  // 内部辅助
  // ==========================================

  private static async cancelAndRemove(type: 'SUMMARY' | 'HABIT' | 'DDL', targetId: string, reminderId: number, reason: string) {
    AppLog.info('Native', `[Scheduler] Canceling ${type}:${targetId} (ID:${reminderId}). Reason: ${reason}`);
    await ReminderUtils.cancel(reminderId);
    await ReminderDataManager.getInstance().removeScoped(type, targetId);
  }

  private static async clearAllDDLReminders(activeReminders: ActiveReminder[], candidates: DDLReminderCandidate[]): Promise<void> {
    const manager = ReminderDataManager.getInstance();
    const idsToCancel = new Set<number>();

    for (const record of activeReminders) {
      idsToCancel.add(record.reminderId);
      idsToCancel.add(Number(record.targetId));
    }
    for (const candidate of candidates) {
      idsToCancel.add(candidate.item.id);
    }

    try {
      const systemReminders = await reminderAgentManager.getValidReminders();
      for (const reminder of systemReminders) {
        const title = typeof reminder.title === 'string' ? reminder.title : '';
        const notificationId = reminder.notificationId;
        if (title.startsWith('任务临近提醒:') || (notificationId !== undefined && idsToCancel.has(notificationId))) {
          if (notificationId !== undefined) {
            idsToCancel.add(notificationId);
          }
        }
      }
    } catch (e) {
      AppLog.warn('Native', `[Scheduler] Failed to enumerate system DDL reminders: ${e}`);
    }

    for (const reminderId of idsToCancel) {
      await ReminderUtils.cancel(reminderId);
    }
    for (const record of activeReminders) {
      await manager.removeScoped(record.type, record.targetId);
    }
  }

  private static async publishAndRecord(ddl: DDLItem, deadlineDate: Date) {
    try {
      // 提前一天提醒
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      const remindTime = new Date(deadlineDate.getTime() - ONE_DAY_MS);
      const now = Date.now();
      const timeStr = formatDeadline(deadlineDate);

      if (remindTime.getTime() < now) {
        AppLog.info('Native', `[Scheduler] Reminder time (${remindTime.toLocaleString()}) is in the past. Skip publishing.`);
        return;
      }

      const contentText = ddl.note ? `${ddl.note} · 截止于 ${timeStr}` : `截止于 ${timeStr}`;

      const reminderId = await ReminderUtils.publishCalendar(
        `任务临近提醒: ${ddl.name}`,
        contentText,
        remindTime,
        ddl.id // 使用业务 ID 确保覆盖
      );

      const newRecord: ActiveReminder = {
        targetId: ddl.id.toString(),
        type: 'DDL',
        reminderId: reminderId,
        triggerTime: deadlineDate.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      AppLog.error('Native', `[Scheduler] Publish DDL failed: ${e}`);
    }
  }

  private static async publishHabit(candidate: HabitReminderCandidate): Promise<void> {
    try {
      AppLog.info('Native', '[Scheduler] Publishing Habit:' + candidate.habit.name + ' at ' + candidate.fireAt.toString());
      const reminderId: number = await ReminderUtils.publishCalendar(
        '打卡提醒: ' + candidate.habit.name,
        '坚持就是胜利！该完成“' + candidate.habit.name + '”了。',
        candidate.fireAt
      );
      const newRecord: ActiveReminder = {
        targetId: candidate.targetId,
        type: 'HABIT',
        reminderId: reminderId,
        triggerTime: candidate.fireAt.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      AppLog.error('Native', `[Scheduler] Publish habit failed: ${e}`);
    }
  }
}

function formatDeadline(date: Date): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  return `${month}月${day}日 ${hour}:${minute}`;
}
