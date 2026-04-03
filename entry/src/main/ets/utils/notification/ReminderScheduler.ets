import { ReminderDataManager } from './ReminderDataManager';
import { ActiveReminder } from '../../model/ActiveReminder';
import { DateTimeUtils } from '../../utils/DateTimeUtils';
import { DDLItem, Habit, HabitStatus } from '../../model/DDLModels';
import { ReminderUtils } from './ReminderUtils';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { LocalValues } from '../../common/local/LocalValues';

const MAX_DDL_SLOTS = 20;

export class ReminderScheduler {

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
        console.warn(`[Scheduler] System returned 0 reminders but local has ${activeReminders.length}. Skipping sync.`);
        return [];
      }

      const systemIds = new Set(systemReminders.map(r => r.notificationId));
      const zombieIds: string[] = [];

      for (const record of activeReminders) {
        if (!systemIds.has(record.reminderId)) {
          console.warn(`[Scheduler] Potential zombie found: ${record.targetId} (ID:${record.reminderId}).`);
          zombieIds.push(record.targetId);
        }
      }
      return zombieIds;
    } catch (e) {
      console.error(`[Scheduler] Sync failed: ${e}.`);
      return [];
    }
  }

  // =========================================================
  // 1. DDL 提醒 (单次 - 使用 Timer 伪装)
  // =========================================================
  static async refreshReminders(allDDLs: DDLItem[]) {
    console.info('[Scheduler] Start refreshing DDLs...');

    const isEnabled = LocalValues.getInstance().getDDLWarning();
    const manager = ReminderDataManager.getInstance();

    let activeReminders = manager.getAll().filter(r => r.type === 'DDL');

    const zombieIds = await ReminderScheduler.syncWithSystem(activeReminders);
    // 这里我们依然保留 activeReminders，但如果发现在 zombieIds 里，我们后续逻辑会自动触发补录
    // 为了保险，我们不直接从 DB 删，而是在补录阶段如果没变化就不动，有变化才重新发

    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => {
      // 如果不是僵尸，才放入 Map
      if (!zombieIds.includes(r.targetId)) {
        activeMap.set(r.targetId, r);
      }
    });

    if (!isEnabled) {
      if (activeReminders.length > 0) {
        console.info('[Scheduler] DDL Warning is DISABLED. Clearing existing reminders...');
        for (const record of activeReminders) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Feature disabled");
        }
      }
      return;
    }

    const now = Date.now();

    interface Candidate {
      item: DDLItem;
      date: Date | null;
      timestamp: number;
    }

    const candidates: Candidate[] = allDDLs
      .filter(item => !item.isCompleted && !item.deleted)
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

    const candidateIds = new Set(candidates.map(c => c.item.id.toString()));

    // --- 阶段 A: 清理 (不在 Top N 或时间变更) ---
    for (const record of activeReminders) {
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Out of range / Completed");
        continue;
      }
      const candidate = candidates.find(c => c.item.id.toString() === record.targetId);
      // 如果截止时间变了，需要重新发布
      if (candidate && Math.abs(candidate.timestamp - record.triggerTime) > 1000) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time changed");
        activeMap.delete(record.targetId);
      }
    }

    // --- 阶段 B: 补录 ---
    for (const c of candidates) {
      const idStr = c.item.id.toString();
      // 如果 activeMap 里还有，说明不需要重新发布
      if (activeMap.has(idStr)) continue;

      // 这里直接传截止日期，publishAndRecord 内部会减去1天
      await ReminderScheduler.publishAndRecord(c.item, c.date!);
    }
  }

  // =========================================================
  // 2. 习惯打卡 (循环 - 使用 Alarm)
  // =========================================================
  static async refreshHabits(allHabits: Habit[]) {
    console.info('[Scheduler] Start refreshing HABIT reminders...');

    const isEnabled = LocalValues.getInstance().getHabitReminder();
    const manager = ReminderDataManager.getInstance();

    let activeReminders = manager.getAll().filter(r => r.type === 'HABIT');
    const zombieIds = await ReminderScheduler.syncWithSystem(activeReminders);

    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => {
      if (!zombieIds.includes(r.targetId)) {
        activeMap.set(r.targetId, r);
      } else {
        manager.remove(r.targetId);
      }
    });

    if (!isEnabled) {
      if (activeReminders.length > 0) {
        console.info('[Scheduler] Habit Reminder is DISABLED. Clearing existing reminders...');
        for (const record of activeReminders) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Feature disabled");
        }
      }
      return;
    }

    // 筛选有效习惯 (Active 且 设置了 alarmTime)
    const candidates = allHabits.filter(h =>
    h.status === HabitStatus.ACTIVE &&
    h.alarmTime && h.alarmTime.length > 0
    );

    const candidateIds = new Set(candidates.map(c => c.id.toString()));

    // --- 阶段 A: 清理 ---
    for (const record of activeReminders) {
      // 习惯已删除 或 已归档 或 删除了提醒时间
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Habit deleted/archived/alarm removed");
        continue;
      }

      // 检查时间 (HH:mm) 是否变化
      const habit = candidates.find(c => c.id.toString() === record.targetId);
      if (habit && habit.alarmTime) {
        const parts = habit.alarmTime.split(':');
        const targetHour = parseInt(parts[0]);
        const targetMinute = parseInt(parts[1]);

        // 获取记录中的时间
        const recordDate = new Date(record.triggerTime);

        if (recordDate.getHours() !== targetHour || recordDate.getMinutes() !== targetMinute) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time(HH:mm) changed");
          activeMap.delete(record.targetId);
        }
      }
    }

    // --- 阶段 B: 发布 ---
    for (const habit of candidates) {
      if (activeMap.has(habit.id.toString())) continue;
      await ReminderScheduler.publishHabit(habit);
    }
  }

  // =========================================================
  // 3. 每日摘要 (循环 - 使用 Alarm)
  // =========================================================
  static async refreshDailySummary(summaryTimeStr: string | null) {
    const TARGET_ID = 'DAILY_SUMMARY';
    const manager = ReminderDataManager.getInstance();
    let existingRecord = manager.getByTargetId(TARGET_ID);

    // 如果 summaryTimeStr 为 null，或者 LocalValues 里关闭了 (双重保障)
    // Settings 页面传参时已经处理了逻辑，传 null 即表示关闭
    if (!summaryTimeStr) {
      if (existingRecord) {
        await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Feature disabled / turned off");
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
        console.info('[Scheduler] Daily Summary time unchanged. Skip.');
        return;
      }
      await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Time update");
    }

    // 发布新提醒
    try {
      const daysOfWeek = [1, 2, 3, 4, 5, 6, 7]; // 每天

      console.info(`[Scheduler] Publishing Daily Summary at ${hour}:${minute}`);

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
      console.error(`[Scheduler] Failed to publish summary: ${e}`);
    }
  }

  // ==========================================
  // 内部辅助
  // ==========================================

  private static async cancelAndRemove(targetId: string, reminderId: number, reason: string) {
    console.info(`[Scheduler] Canceling ${targetId} (ID:${reminderId}). Reason: ${reason}`);
    await ReminderUtils.cancel(reminderId);
    await ReminderDataManager.getInstance().remove(targetId);
  }

  private static async publishAndRecord(ddl: DDLItem, deadlineDate: Date) {
    try {
      // 提前一天提醒
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      const remindTime = new Date(deadlineDate.getTime() - ONE_DAY_MS);
      const now = Date.now();
      const timeStr = formatDeadline(deadlineDate);

      if (remindTime.getTime() < now) {
        console.info(`[Scheduler] Reminder time (${remindTime.toLocaleString()}) is in the past. Skip publishing.`);
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
      console.error(`[Scheduler] Publish DDL failed: ${e}`);
    }
  }

  private static async publishHabit(habit: Habit) {
    if (!habit.alarmTime) return;
    try {
      const parts = habit.alarmTime.split(':');
      const hour = parseInt(parts[0]);
      const minute = parseInt(parts[1]);
      const daysOfWeek = [1, 2, 3, 4, 5, 6, 7];

      console.info(`[Scheduler] Publishing Habit:${habit.name} at ${hour}:${minute}`);

      const reminderId = await ReminderUtils.publishAlarm(
        `打卡提醒: ${habit.name}`,
        `坚持就是胜利！该完成"${habit.name}"了。`,
        hour,
        minute,
        daysOfWeek,
        habit.id // 使用业务 ID 确保覆盖
      );

      const recordTime = new Date();
      recordTime.setHours(hour, minute, 0, 0);

      const newRecord: ActiveReminder = {
        targetId: habit.id.toString(),
        type: 'HABIT',
        reminderId: reminderId,
        triggerTime: recordTime.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      console.error(`[Scheduler] Publish habit failed: ${e}`);
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