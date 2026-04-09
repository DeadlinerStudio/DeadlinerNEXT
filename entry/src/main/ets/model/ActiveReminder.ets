export type ActiveReminderType = 'SUMMARY' | 'HABIT' | 'DDL';

/**
 * 记录当前已发布到系统的提醒
 * 用于在本地持久化存储，建立 业务ID <-> 系统通知ID 的映射
 */
export interface ActiveReminder {
  /**
   * 业务对象的唯一标识 (例如 DDLItem.id 或 Habit.id)
   * 对于每日汇总，可以固定为 "DAILY_SUMMARY"
   */
  targetId: string;

  /**
   * 提醒类型
   */
  type: ActiveReminderType;

  /**
   * 鸿蒙系统 ReminderAgent 返回的 notificationId
   * 用于后续调用 cancelReminder(id)
   */
  reminderId: number;

  /**
   * 预定的触发时间戳 (ms)
   * 用于校验：如果 DDL 时间改了，对比这个时间戳发现不一致，就需要重新发布
   */
  triggerTime: number;
}

export function buildActiveReminderScopeKey(type: ActiveReminderType, targetId: string): string {
  return `${type}:${targetId}`;
}
