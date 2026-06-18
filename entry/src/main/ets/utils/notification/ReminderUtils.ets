import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class ReminderUtils {

  /**
   * 发布单次提醒 (用于 DDL)
   * 【核心修改】由于 Calendar 是 System API，这里内部自动转换为 Timer (倒计时) 实现。
   * 只要发布成功，系统就会接管倒计时，App 杀死后依然有效。
   */
  static async publishCalendar(title: string, content: string, targetTime: Date, notificationId?: number): Promise<number> {
    const reminderId = notificationId ?? ReminderUtils.generateId();

    // 1. 计算时间差 (单位：秒)
    const now = Date.now();
    const target = targetTime.getTime();

    // 计算剩余秒数
    let diffInSeconds = Math.floor((target - now) / 1000);

    // 防御性处理：如果时间是过去的，或者太近（小于1秒），强制设为 1 秒后触发，避免报错
    if (diffInSeconds < 1) {
      console.warn(`[ReminderUtils] Target time is too close or past. Adjusting to 1s.`);
      diffInSeconds = 1;
    }

    // 2. 使用 Timer 模拟 Calendar
    let targetReminder: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      triggerTimeInSeconds: diffInSeconds, // 核心：把日期转换为秒数

      title: title,
      content: content,
      actionButton: [
        { title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE },
        { title: '稍后', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE }
      ],
      wantAgent: {
        pkgName: 'com.aritxonly.deadliner',
        abilityName: 'EntryAbility'
      },
      snoozeTimes: 1,
      timeInterval: 5 * 60, // 5分钟后再次提醒
      notificationId: reminderId,
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      ringDuration: 0,
    };

    console.info(`[ReminderUtils] Converting Calendar to Timer. Target: ${targetTime.toLocaleTimeString()} (in ${diffInSeconds}s)`);
    return await ReminderUtils.publish(targetReminder);
  }

  /**
   * 发布循环闹钟提醒 (用于 每日摘要 / 习惯)
   * 【核心修改】使用 Alarm 类型，支持原生重复，无需计算日期，只关心 HH:mm
   * @param daysOfWeek 1=周一, 7=周日. 传入 [1,2,3,4,5,6,7] 代表每天
   */
  static async publishAlarm(title: string, content: string, hour: number, minute: number, daysOfWeek: number[], notificationId?: number): Promise<number> {
    const reminderId = notificationId ?? ReminderUtils.generateId();

    let targetReminder: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek, // Alarm 独有的重复属性

      title: title,
      content: content,
      actionButton: [
        { title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE },
        { title: '稍后', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE }
      ],
      wantAgent: {
        pkgName: 'com.aritxonly.deadliner',
        abilityName: 'EntryAbility'
      },
      snoozeTimes: 1,
      timeInterval: 5 * 60,
      notificationId: reminderId,
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      ringDuration: 0,
    };

    return await ReminderUtils.publish(targetReminder);
  }

  // 通用发布逻辑
  private static async publish(reminder: reminderAgentManager.ReminderRequest): Promise<number> {
    try {
      console.info(`[ReminderUtils] Publishing ID:${reminder.notificationId} Type:${reminder.reminderType}`);
      return await reminderAgentManager.publishReminder(reminder);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[ReminderUtils] FAILED: Code=${error.code}, Msg=${error.message}`);
      throw Error(error.message);
    }
  }

  // 通用取消逻辑
  static async cancel(reminderId: number) {
    try {
      await reminderAgentManager.cancelReminder(reminderId);
      console.info(`[ReminderUtils] Canceled ID: ${reminderId}`);
    } catch (e) {
      // 忽略 ID 不存在的错误
    }
  }

  static async clearAll() {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (e) {}
  }

  private static generateId(): number {
    // 限制 ID 范围，防止溢出。如果不传入固定 ID，回退到基于时间的低频冲突 ID
    return Math.floor(Math.random() * 1000000);
  }
}
