import { AppLog } from '../logging/AppLog';
import { LocalValues } from '../local/LocalValues';
import { DDLItem, DeadlineType, SubTask } from '../../model/DDLModels';
import { TaskState, TaskStateAction } from '../../model/TaskStateMachine';
import { common } from '@kit.AbilityKit';
import { WidgetUpdater } from '../../utils/WidgetUpdater';
import { ReminderScheduler } from '../../utils/notification/ReminderScheduler';
import { KmpTaskRepositoryAdapter, TaskCreateParams } from '../kmp/KmpTaskRepositoryAdapter';
import { KmpPersistenceService } from '../kmp/KmpPersistenceService';
import { KmpMigrationService } from '../migration/KmpMigrationService';

interface KmpWebDavSyncOutcome {
  succeeded: boolean;
  remoteApplied: number;
  remoteIgnored: number;
  failureMessage?: string | null;
}

/** KMP is the sole task source; this repository only keeps the ArkTS-facing API stable. */
export class TaskRepository {
  private static instance: TaskRepository;
  private context: common.Context | null = null;
  private readonly kmpTasks: KmpTaskRepositoryAdapter = new KmpTaskRepositoryAdapter();
  private taskCache: DDLItem[] | null = null;
  private pendingTaskRead: Promise<DDLItem[]> | null = null;
  private syncTimer: number = -1;
  private readonly syncDelayMs: number = 400;
  private widgetUpdateTimer: number = -1;
  private readonly widgetUpdateDelayMs: number = 500;
  private reminderUpdateTimer: number = -1;
  private readonly reminderUpdateDelayMs: number = 800;
  private isSyncing: boolean = false;
  private hasPendingSync: boolean = false;

  private constructor() {}

  public static getInstance(): TaskRepository {
    if (!TaskRepository.instance) TaskRepository.instance = new TaskRepository();
    return TaskRepository.instance;
  }

  public setContext(context: common.Context): void {
    this.context = context;
  }

  private async initializeKmp(): Promise<void> {
    if (this.context === null) throw new Error('TaskRepository context is required for KMP persistence');
    await KmpMigrationService.getInstance().awaitReady();
    await this.kmpTasks.initialize(this.context);
  }

  private inBasicMode(): boolean {
    return LocalValues.getInstance().getBasicMode();
  }

  private notifyDataChange(): void {
    const currentRevision: number = AppStorage.get<number>('KmpDataRevision') ?? 0;
    AppStorage.setOrCreate('KmpDataRevision', currentRevision + 1);
    if (this.context !== null) this.context.eventHub.emit('sync_done');
  }

  private triggerUpdates(): void {
    this.notifyDataChange();
    this.scheduleSync();
    this.scheduleWidgetUpdate();
    this.scheduleReminderRefresh();
  }

  public triggerExternalUpdates(): void {
    this.triggerUpdates();
  }

  public async insertDDL(params: TaskCreateParams): Promise<number> {
    await this.initializeKmp();
    const id: number = await this.kmpTasks.create(params);
    this.invalidateTaskCache();
    this.triggerUpdates();
    return id;
  }

  public async createDDLWithSubTasks(ddlParams: TaskCreateParams, subTasks: string[]): Promise<number> {
    await this.initializeKmp();
    const ddlId: number = await this.kmpTasks.create(ddlParams);
    for (let index = 0; index < subTasks.length; index++) {
      await this.kmpTasks.insertSubtask(ddlId, subTasks[index], index);
    }
    this.invalidateTaskCache();
    this.triggerUpdates();
    return ddlId;
  }

  public async updateDDL(item: DDLItem): Promise<void> {
    await this.initializeKmp();
    await this.kmpTasks.update(item);
    this.invalidateTaskCache();
    if (!ReminderScheduler.shouldScheduleDDLReminder(item)) await ReminderScheduler.cancelDDLReminder(item.id);
    this.triggerUpdates();
  }

  public async deleteDDL(id: number): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpTasks.delete(id)) throw new Error('KMP task not found for deletion');
    this.invalidateTaskCache();
    await ReminderScheduler.cancelDDLReminder(id);
    this.triggerUpdates();
  }

  public async getAllDDLs(): Promise<DDLItem[]> {
    return this.readTasks();
  }

  public async getDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    if (type !== DeadlineType.TASK) return [];
    return this.readTasks();
  }

  public async getMainListDDLsByType(type: DeadlineType): Promise<DDLItem[]> {
    if (type !== DeadlineType.TASK) return [];
    const tasks: DDLItem[] = await this.readTasks();
    return tasks.filter((item: DDLItem): boolean => item.state === TaskState.ACTIVE || item.state === TaskState.COMPLETED || item.state === TaskState.ABANDONED);
  }

  public async getArchivedDDLs(): Promise<DDLItem[]> {
    const tasks: DDLItem[] = await this.readTasks();
    return tasks.filter((item: DDLItem): boolean => item.state === TaskState.ARCHIVED || item.state === TaskState.ABANDONED_ARCHIVED);
  }

  public async getDDLById(id: number): Promise<DDLItem | null> {
    const tasks: DDLItem[] = await this.readTasks();
    for (let index = 0; index < tasks.length; index++) {
      if (tasks[index].id === id) return tasks[index];
    }
    return null;
  }

  public async transitionDDL(id: number, action: TaskStateAction): Promise<DDLItem> {
    await this.initializeKmp();
    const updated: DDLItem | null = await this.kmpTasks.applyAction(id, action);
    if (updated === null) throw new Error('KMP task not found for state transition');
    this.invalidateTaskCache();
    if (!ReminderScheduler.shouldScheduleDDLReminder(updated)) await ReminderScheduler.cancelDDLReminder(updated.id);
    this.triggerUpdates();
    return updated;
  }

  public async getSubTasks(ddlId: number): Promise<SubTask[]> {
    await this.initializeKmp();
    const subtasks: SubTask[] | null = await this.kmpTasks.subtasksForTask(ddlId);
    if (subtasks === null) throw new Error('KMP task not found for subtask query');
    return subtasks;
  }

  public async insertSubTask(ddlId: number, content: string, order: number): Promise<number> {
    await this.initializeKmp();
    const id: number = await this.kmpTasks.insertSubtask(ddlId, content, order);
    this.invalidateTaskCache();
    this.triggerUpdates();
    return id;
  }

  public async toggleSubTask(subTask: SubTask): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpTasks.toggleSubtask(subTask.id, !subTask.isCompleted)) throw new Error('KMP subtask not found');
    this.invalidateTaskCache();
    this.triggerUpdates();
  }

  public async deleteSubTask(subTaskId: number): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpTasks.deleteSubtask(subTaskId)) throw new Error('KMP subtask not found');
    this.invalidateTaskCache();
    this.triggerUpdates();
  }

  public async updateSubTaskContent(subTaskId: number, content: string): Promise<void> {
    await this.initializeKmp();
    if (!await this.kmpTasks.updateSubtaskContent(subTaskId, content)) throw new Error('KMP subtask not found');
    this.invalidateTaskCache();
    this.triggerUpdates();
  }

  public async syncNow(): Promise<boolean> {
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
      this.syncTimer = -1;
    }
    if (this.isSyncing) return false;
    this.isSyncing = true;
    try {
      await this.initializeKmp();
      await this.syncKmpWebDav();
      this.invalidateTaskCache();
      this.notifyDataChange();
      this.performWidgetUpdate();
      this.scheduleReminderRefresh();
      return true;
    } catch (error) {
      AppLog.error('Native', '[TaskRepo] KMP manual sync failed: ' + String(error));
      return false;
    } finally {
      this.isSyncing = false;
      if (this.hasPendingSync) this.performSync();
    }
  }

  private async syncKmpWebDav(): Promise<void> {
    if (LocalValues.getInstance().getSyncMode() !== 'webdav') {
      throw new Error('KMP persistence currently supports changelog sync through WebDAV only');
    }
    const url: string = LocalValues.getInstance().getWebDavUrl();
    if (url.length === 0) throw new Error('WebDAV URL not set');
    const auth = LocalValues.getInstance().getWebDavAuth();
    const rawResult: string = await KmpPersistenceService.getInstance().syncWebDavChangeLogJson(url, auth.user, auth.pass);
    const result: KmpWebDavSyncOutcome = JSON.parse(rawResult) as KmpWebDavSyncOutcome;
    if (!result.succeeded) {
      throw new Error(result.failureMessage ?? 'KMP WebDAV changelog sync failed');
    }
  }

  /** Coalesces first-frame consumers so ArkUI crosses the synchronous NAPI boundary only once. */
  private async readTasks(): Promise<DDLItem[]> {
    await this.initializeKmp();
    if (this.taskCache !== null) return this.taskCache;
    if (this.pendingTaskRead !== null) return this.pendingTaskRead;

    const pending: Promise<DDLItem[]> = this.loadTasksIntoCache();
    this.pendingTaskRead = pending;
    try {
      return await pending;
    } finally {
      this.pendingTaskRead = null;
    }
  }

  private async loadTasksIntoCache(): Promise<DDLItem[]> {
    const tasks: DDLItem[] = await this.kmpTasks.listTasks();
    this.taskCache = tasks;
    return tasks;
  }

  private invalidateTaskCache(): void {
    this.taskCache = null;
  }

  private scheduleWidgetUpdate(): void {
    if (this.widgetUpdateTimer !== -1) clearTimeout(this.widgetUpdateTimer);
    this.widgetUpdateTimer = setTimeout(() => {
      this.performWidgetUpdate();
    }, this.widgetUpdateDelayMs);
  }

  private performWidgetUpdate(): void {
    if (this.context !== null) WidgetUpdater.updateAllWidgets(this.context);
    this.widgetUpdateTimer = -1;
  }

  private scheduleReminderRefresh(): void {
    if (this.reminderUpdateTimer !== -1) clearTimeout(this.reminderUpdateTimer);
    this.reminderUpdateTimer = setTimeout(() => {
      this.performReminderRefresh();
    }, this.reminderUpdateDelayMs);
  }

  private async performReminderRefresh(): Promise<void> {
    try {
      await ReminderScheduler.refreshReminders(await this.getAllDDLs());
    } catch (error) {
      AppLog.error('Native', '[TaskRepo] Reminder refresh failed: ' + String(error));
    } finally {
      this.reminderUpdateTimer = -1;
    }
  }

  public async initialReminderCheck(): Promise<void> {
    this.scheduleReminderRefresh();
  }

  public async checkAndAutoArchive(): Promise<void> {
    const archiveDays: number = LocalValues.getInstance().getAutoArchiveDays();
    if (archiveDays <= 0) return;
    const threshold: number = Date.now() - archiveDays * 24 * 60 * 60 * 1000;
    const tasks: DDLItem[] = await this.getAllDDLs();
    let archivedCount: number = 0;
    for (let index = 0; index < tasks.length; index++) {
      const task: DDLItem = tasks[index];
      if (task.state !== TaskState.COMPLETED || task.completeTime.length === 0) continue;
      if (new Date(task.completeTime).getTime() > threshold) continue;
      const archived: DDLItem | null = await this.kmpTasks.applyAction(task.id, TaskStateAction.MARK_ARCHIVE);
      if (archived !== null) archivedCount++;
    }
    if (archivedCount > 0) this.triggerUpdates();
  }
}
