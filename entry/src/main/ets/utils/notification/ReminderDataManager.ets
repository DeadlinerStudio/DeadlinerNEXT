import dataPreferences from '@ohos.data.preferences';
import { ActiveReminder, ActiveReminderType, buildActiveReminderScopeKey } from '../../model/ActiveReminder';
import common from '@ohos.app.ability.common';

const PREF_NAME = 'deadline_reminder_pref';
const KEY_ACTIVE_REMINDERS = 'active_reminders_json';

export class ReminderDataManager {
  private static instance: ReminderDataManager;
  private preferences: dataPreferences.Preferences | null = null;
  // 内存缓存，减少频繁 IO
  private memoryCache: ActiveReminder[] = [];

  private constructor() {}

  public static getInstance(): ReminderDataManager {
    if (!ReminderDataManager.instance) {
      ReminderDataManager.instance = new ReminderDataManager();
    }
    return ReminderDataManager.instance;
  }

  /**
   * 初始化 (通常在 EntryAbility 的 onCreate 或 onWindowStageCreate 调用)
   */
  async init(context: common.Context) {
    try {
      this.preferences = await dataPreferences.getPreferences(context, PREF_NAME);
      await this.loadFromDisk();
    } catch (err) {
      console.error(`[ReminderData] Init failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 从磁盘加载数据到内存
   */
  private async loadFromDisk() {
    if (!this.preferences) return;
    try {
      const jsonStr = await this.preferences.get(KEY_ACTIVE_REMINDERS, '[]') as string;
      this.memoryCache = JSON.parse(jsonStr) as ActiveReminder[];
      console.info(`[ReminderData] Loaded ${this.memoryCache.length} records.`);
    } catch (e) {
      console.error('[ReminderData] Load parse failed, resetting.');
      this.memoryCache = [];
    }
  }

  /**
   * 保存内存数据到磁盘
   */
  private async saveToDisk() {
    if (!this.preferences) return;
    try {
      const jsonStr = JSON.stringify(this.memoryCache);
      await this.preferences.put(KEY_ACTIVE_REMINDERS, jsonStr);
      await this.preferences.flush();
    } catch (e) {
      console.error(`[ReminderData] Save failed: ${JSON.stringify(e)}`);
    }
  }

  // ==========================================
  // 核心操作 API
  // ==========================================

  /**
   * 获取所有当前活跃的提醒
   */
  getAll(): ActiveReminder[] {
    return [...this.memoryCache]; // 返回副本
  }

  getAllByType(type: ActiveReminderType): ActiveReminder[] {
    return this.memoryCache.filter(r => r.type === type);
  }

  /**
   * 根据业务ID查找提醒记录
   */
  getByTargetId(targetId: string): ActiveReminder | undefined {
    return this.memoryCache.find(r => r.targetId === targetId);
  }

  getByScopedTarget(type: ActiveReminderType, targetId: string): ActiveReminder | undefined {
    const scopeKey = buildActiveReminderScopeKey(type, targetId);
    return this.memoryCache.find(r => buildActiveReminderScopeKey(r.type, r.targetId) === scopeKey);
  }

  /**
   * 添加或更新记录
   * @param record
   */
  async addOrUpdate(record: ActiveReminder) {
    const recordKey = buildActiveReminderScopeKey(record.type, record.targetId);
    const existing = this.memoryCache.find(r => buildActiveReminderScopeKey(r.type, r.targetId) === recordKey);
    if (existing) {
      console.info(`[ReminderData] Updating existing record: ${recordKey}. Old SystemID:${existing.reminderId} New SystemID:${record.reminderId}`);
    } else {
      console.info(`[ReminderData] Adding new record: ${recordKey} -> SystemID:${record.reminderId}`);
    }
    this.memoryCache = this.memoryCache.filter(r => buildActiveReminderScopeKey(r.type, r.targetId) !== recordKey);
    this.memoryCache.push(record);
    await this.saveToDisk();
  }

  /**
   * 移除记录 (仅从表里删，不负责调用系统 cancel)
   * @param targetId 业务ID
   */
  async remove(targetId: string) {
    const before = this.memoryCache.length;
    this.memoryCache = this.memoryCache.filter(r => r.targetId !== targetId);
    if (this.memoryCache.length !== before) {
      console.info(`[ReminderData] Removed record for: ${targetId}`);
      await this.saveToDisk();
    } else {
      console.warn(`[ReminderData] Attempted to remove non-existent record: ${targetId}`);
    }
  }

  async removeScoped(type: ActiveReminderType, targetId: string) {
    const scopeKey = buildActiveReminderScopeKey(type, targetId);
    const before = this.memoryCache.length;
    this.memoryCache = this.memoryCache.filter(r => buildActiveReminderScopeKey(r.type, r.targetId) !== scopeKey);
    if (this.memoryCache.length !== before) {
      console.info(`[ReminderData] Removed record for: ${scopeKey}`);
      await this.saveToDisk();
    } else {
      console.warn(`[ReminderData] Attempted to remove non-existent record: ${scopeKey}`);
    }
  }

  /**
   * 清空所有记录
   */
  async clear() {
    this.memoryCache = [];
    await this.saveToDisk();
  }
}
