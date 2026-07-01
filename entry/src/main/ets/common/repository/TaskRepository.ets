import { DatabaseHelper, DDLInsertParams } from '../data/DatabaseHelper';
import { SyncService } from '../sync/SyncService';
import { WebUtils } from '../network/WebUtils';
import { LocalValues } from '../local/LocalValues';
import { DDLItem, DeadlineType, SubTask } from '../../model/DDLModels';
import { TaskStateAction } from '../../model/TaskStateMachine';
import { common } from '@kit.AbilityKit';
import { WidgetUpdater } from '../../utils/WidgetUpdater';
import { ReminderScheduler } from '../../utils/notification/ReminderScheduler';
import { ISyncProvider } from '../sync/SyncProvider';
import { CloudSyncProvider } from '../sync/CloudSyncProvider';
import { WebDavProvider } from '../sync/WebDavProvider';

export class TaskRepository {
  private static instance: TaskRepository;
  private db: DatabaseHelper;
  private context: common.Context | null = null;

  // 去抖动定时器
  private syncTimer: number = -1;
  private readonly SYNC_DELAY_MS = 400;

  // Widget 更新的防抖定时器
  private widgetUpdateTimer: number = -1;
  private readonly WIDGET_UPDATE_DELAY_MS = 500;

  private isSyncing: boolean = false;      // 是否正在同步中
  private hasPendingSync: boolean = false; // 是否在同步期间又有新请求

  private constructor() {
    this.db = DatabaseHelper.getInstance();
  }

  public static getInstance(): TaskRepository {
    if (!TaskRepository.instance) {
      TaskRepository.instance = new TaskRepository();
    }
    return TaskRepository.instance;
  }

  public setContext(context: common.Context) {
    this.context = context;
  }

  private createSyncProvider(): ISyncProvider | null {
    if (!this.context) {
      console.warn('[TaskRepo] Context is null, cannot create SyncProvider.');
      return null;
    }

    const syncMode = LocalValues.getInstance().getSyncMode();

    if (syncMode === 'cloud') {
      return new CloudSyncProvider(this.context);
    } else if (syncMode === 'webdav') {
      const url = LocalValues.getInstance().getWebDavUrl();
      if (!url) {
        console.warn('[TaskRepo] WebDAV URL not set.');
        return null;
      }
      const webAuth = LocalValues.getInstance().getWebDavAuth();
      const web = new WebUtils(url, webAuth.user, webAuth.pass);
      return new WebDavProvider(web);
    } else {
      console.warn(`[TaskRepo] Unknown sync mode: ${syncMode}`);
      return null;
    }
  }

  private async ensureDbReady(): Promise<void> {
    if (this.db.isReady()) return;

    console.warn('[TaskRepo] DB not ready. Polling...');
    if (this.context) {
      this.db.init(this.context);
    }

    const maxRetries = 40;
    for (let i = 0; i < maxRetries; i++) {
      if (this.db.isReady()) return;
      await new Promise<void>(resolve => setTimeout(resolve, 50));
    }
    throw new Error('[TaskRepo] Fatal: DB Init Timeout.');
  }

  private inBasicMode(): boolean {
    return LocalValues.getInstance().getBasicMode();
  }

  private notifyDataChange() {
    if (this.context) {
      console.log('[Event] notifyDataChange()');
      this.context.eventHub.emit('sync_done');
    }
  }

  // ==========================================
  // 核心：调度逻辑 (防抖 + 串行化)
  // ==========================================
  private scheduleSync() {
    // 1. 防抖：如果有未执行的定时器，重置它
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
    }

    // 2. 检查开关
    if (!LocalValues.getInstance().getCloudSyncEnable()) {
      return;
    }

    // 3. 启动定时器
    this.syncTimer = setTimeout(() => {
      this.performSync();
    }, this.SYNC_DELAY_MS);
  }

  /**
   * 真正执行同步的方法 (串行控制)
   */
  private async performSync() {
    if (this.inBasicMode()) return;

    // A. 如果当前正在同步，不要打断，标记“稍后再试”并退出
    if (this.isSyncing) {
      console.info('[TaskRepo] Sync is running. Marking pending...');
      this.hasPendingSync = true;
      return;
    }

    // B. 开始同步
    this.isSyncing = true;
    this.hasPendingSync = false; // 清除标记

    console.info('[TaskRepo] Starting auto-sync...');

    try {
      const provider = this.createSyncProvider();
      if (!provider) return;

      const syncService = new SyncService(this.db, provider);

      await syncService.syncOnce();

      console.info('[TaskRepo] Auto-sync success.');

      if (this.context) {
        this.context.eventHub.emit('sync_done');
      }
    } catch (e) {
      console.error(`[TaskRepo] Auto-sync failed: ${e}`);
    } finally {
      // C. 同步结束，释放锁
      this.isSyncing = false;

      // D. 检查在同步期间是否有新请求
      if (this.hasPendingSync) {
        console.info('[TaskRepo] Found pending request. Syncing again immediately...');
        // 递归调用（或者再次 setTimeout），处理积压的变更
        this.performSync();
      }
    }
  }

  private triggerUpdates() {
    this.notifyDataChange();
    this.scheduleSync(); // 触发调度
    this.scheduleWidgetUpdate();
    this.scheduleReminderRefresh();
  }

  public triggerExternalUpdates() {
    this.triggerUpdates();
  }

  // ==========================================
  // 增删改查
  // ==========================================

  async insertDDL(params: DDLInsertParams): Promise<number> {
    await this.ensureDbReady();
    const id = await this.db.insertDDL(params);
    this.triggerUpdates();
    return id;
  }

  async createDDLWithSubTasks(ddlParams: DDLInsertParams, subTasks: string[]): Promise<number> {
    await this.ensureDbReady();

    // 使用 runInTransaction 保证原子性
    const resultId = await this.db.runInTransaction(async () => {
      // 1. 创建父任务
      const ddlId = await this.db.insertDDL(ddlParams);
      if (ddlId <= 0) return -1;

      // 2. 批量创建子任务
      for (let i = 0; i < subTasks.length; i++) {
        const content = subTasks[i];
        await this.db.insertSubTask({
          ddlId: ddlId,
          content: content,
          isCompleted: false,
          sortOrder: i // 保持顺序
        });
      }
      return ddlId;
    });

    if (resultId && resultId > 0) {
      this.triggerUpdates();
    }
    return resultId ?? -1;
  }

  async updateDDL(item: DDLItem): Promise<void> {
    await this.ensureDbReady();
    await this.db.updateDDL(item);
    if (!ReminderScheduler.shouldScheduleDDLReminder(item)) {
      await ReminderScheduler.cancelDDLReminder(item.id);
    }
    this.triggerUpdates();
  }

  async deleteDDL(id: number): Promise<void> {
    await this.ensureDbReady();
    await this.db.deleteDDL(id);
    await ReminderScheduler.cancelDDLReminder(id);
    this.triggerUpdates();
  }

  async getAllDDLs(): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getAllDDLs();
  }

  async getDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getDDLsByType(type);
  }

  async getMainListDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getMainListDDLsByType(type);
  }

  async getArchivedDDLs(): Promise<DDLItem[]> {
    await this.ensureDbReady();
    return this.db.getArchivedDDLs();
  }

  async getDDLById(id: number): Promise<DDLItem | null> {
    await this.ensureDbReady();
    return this.db.getDDLById(id);
  }

  async transitionDDL(id: number, action: TaskStateAction): Promise<DDLItem> {
    await this.ensureDbReady();
    const item = await this.db.transitionDDLState(id, action);
    if (!ReminderScheduler.shouldScheduleDDLReminder(item)) {
      await ReminderScheduler.cancelDDLReminder(item.id);
    }
    this.triggerUpdates();
    return item;
  }

  private scheduleWidgetUpdate() {
    // 1. 如果已有挂起的更新任务，取消它（重新计时）
    if (this.widgetUpdateTimer !== -1) {
      clearTimeout(this.widgetUpdateTimer);
    }

    // 2. 启动新的定时器
    this.widgetUpdateTimer = setTimeout(() => {
      this.performWidgetUpdate();
    }, this.WIDGET_UPDATE_DELAY_MS);
  }

  private performWidgetUpdate() {
    const context = this.context;
    if (context) {
      console.info('[TaskRepo] Updating widgets now...');
      WidgetUpdater.updateAllWidgets(context);
    }
    this.widgetUpdateTimer = -1;
  }

  async getSubTasks(ddlId: number): Promise<SubTask[]> {
    await this.ensureDbReady();
    return this.db.getSubTasksByDDL(ddlId);
  }

  async insertSubTask(ddlId: number, content: string, order: number): Promise<number> {
    await this.ensureDbReady();
    const id = await this.db.insertSubTask({
      ddlId: ddlId,
      content: content,
      isCompleted: false,
      sortOrder: order
    });
    this.triggerUpdates();
    return id;
  }

  async toggleSubTask(subTask: SubTask): Promise<void> {
    await this.ensureDbReady();

    await this.db.updateSubTaskStatus(subTask.id, !subTask.isCompleted);

    this.triggerUpdates();
  }

  async deleteSubTask(subTaskId: number): Promise<void> {
    await this.ensureDbReady();
    await this.db.deleteSubTask(subTaskId);
    this.triggerUpdates();
  }

  async updateSubTaskContent(subTaskId: number, content: string): Promise<void> {
    await this.ensureDbReady();
    await this.db.updateSubTaskContent(subTaskId, content);
    this.triggerUpdates();
  }

  // ==========================================
  // 手动同步
  // ==========================================
  async syncNow(): Promise<boolean> {
    await this.ensureDbReady();

    // 取消由于防抖挂起的任务，直接插队执行
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
      this.syncTimer = -1;
    }

    // 复用串行逻辑，防止手动和自动冲突
    // 但 syncNow 需要返回结果，所以这里特殊处理一下，等待 performSync 完成不太容易
    // 简单起见，手动同步强制执行逻辑（需注意，如果正在自动同步，可能会冲突，
    // 更好的做法是让 syncNow 也走 performSync 逻辑，或者等待锁释放）

    // 这里采用简单策略：如果正在同步，直接报错或返回 false
    if (this.isSyncing) {
      console.warn('[TaskRepo] Sync already running. Manual sync ignored.');
      return false;
    }

    this.isSyncing = true;
    try {
      const provider = this.createSyncProvider();
      if (!provider) return false;

      const syncService = new SyncService(this.db, provider);
      const result = await syncService.syncOnce();

      if (result.success && result.hasLocalChanges && this.context) {
        this.notifyDataChange();
        this.performWidgetUpdate();
        this.scheduleReminderRefresh();
      }
      return result.success;
    } finally {
      this.isSyncing = false;
      // 手动同步完，也检查一下pending
      if (this.hasPendingSync) {
        this.performSync();
      }
    }
  }

  private reminderUpdateTimer: number = -1;
  private readonly REMINDER_UPDATE_DELAY_MS = 800;

  private scheduleReminderRefresh() {
    // 1. 如果有挂起的任务，取消重置
    if (this.reminderUpdateTimer !== -1) {
      clearTimeout(this.reminderUpdateTimer);
    }

    // 2. 启动定时器
    this.reminderUpdateTimer = setTimeout(() => {
      this.performReminderRefresh();
    }, this.REMINDER_UPDATE_DELAY_MS);
  }

  private async performReminderRefresh() {
    try {
      await this.ensureDbReady();
      console.info('[TaskRepo] Triggering Reminder Scheduler...');

      // 1. 获取所有数据 (Scheduler 内部会过滤已完成和已删除的)
      const allDDLs = await this.db.getAllDDLs();

      // 2. 交给调度器计算
      await ReminderScheduler.refreshReminders(allDDLs);

    } catch (e) {
      console.error(`[TaskRepo] Reminder refresh failed: ${e}`);
    } finally {
      this.reminderUpdateTimer = -1;
    }
  }

  public async initialReminderCheck() {
    console.info('[TaskRepo] performing initial reminder check...');

    this.scheduleReminderRefresh();
  }

  /**
   * 检查并执行自动归档
   */
  public async checkAndAutoArchive() {
    // 1. 获取用户设置的归档天数 (从 LocalValues)
    const archiveDays = LocalValues.getInstance().getAutoArchiveDays(); // 假设你已实现此方法

    if (archiveDays <= 0) return;

    try {
      await this.ensureDbReady();
      const archivedCount = await this.db.autoArchiveDDLs(archiveDays);

      if (archivedCount > 0) {
        // 2. 如果有变更，通知 UI
        this.notifyDataChange();
        // 3. 触发同步和 Widget 更新
        this.scheduleSync();
        this.scheduleWidgetUpdate();
        this.scheduleReminderRefresh();
      }
    } catch (e) {
      console.error(`[TaskRepo] checkAndAutoArchive failed: ${e}`);
    }
  }
}
