import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { DeadlineType, DDLItem, SubTask } from '../../model/DDLModels';
import { TaskState, TaskStateAction } from '../../model/TaskStateMachine';
import { FocusChangeConfirmation } from '../../pages/routes/focus/FocusChangeConfirmation';
import { KmpPersistenceService } from './KmpPersistenceService';

interface KmpTaskSubtaskPayload {
  uid: string;
  taskUid: string;
  content: string;
  isCompleted: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

interface KmpTaskPayload {
  uid: string;
  title: string;
  note: string;
  startAt: string | null;
  dueAt: string | null;
  state: TaskState;
  completedAt: string | null;
  categoryUid: string | null;
  isStarred: boolean;
  calendarEventId: number | null;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
  subtasks: KmpTaskSubtaskPayload[];
}

interface ActiveFocusTimerGuardPayload {
  taskUid: string;
  target?: FocusTargetGuardPayload | null;
}
interface FocusTargetGuardPayload { kind: string; uid: string; }

interface FocusTimerGuardStatePayload {
  timer: ActiveFocusTimerGuardPayload | null;
}

export interface TaskCreateParams {
  name: string;
  startTime: string;
  endTime: string;
  state?: TaskState;
  isCompleted: boolean;
  completeTime: string;
  note: string;
  isArchived: boolean;
  isStared: boolean;
  type: DeadlineType;
  calendarEventId: number | null;
  categoryUid?: string | null;
}

export interface LegacyTaskIdentifier {
  uid: string;
  id: number;
  type: DeadlineType;
  subtasks: LegacySubtaskIdentifier[];
}

export interface LegacySubtaskIdentifier {
  uid: string;
  id: number;
}

/**
 * Projects the KMP task ViewModel into the numeric identifiers that the current ArkTS UI still
 * consumes. The mapping is stored independently from ArkData, so later UI UID migration does not
 * require rewriting either KMP records or legacy RDB rows.
 */
export class KmpTaskRepositoryAdapter {
  private static readonly PREFERENCE_NAME: string = 'kmp_task_compatibility';
  private static readonly NEXT_ID_KEY: string = 'next_synthetic_id';
  private static readonly TASK_ID_PREFIX: string = 'task_uid:';
  private static readonly SUBTASK_ID_PREFIX: string = 'subtask_uid:';
  private static readonly TYPE_PREFIX: string = 'legacy_type_uid:';
  private static readonly FIRST_SYNTHETIC_ID: number = 1000000000;

  private readonly persistence: KmpPersistenceService = KmpPersistenceService.getInstance();
  private store: preferences.Preferences | null = null;

  public async initialize(context: common.Context): Promise<void> {
    if (this.store !== null) return;
    this.store = await preferences.getPreferences(context, KmpTaskRepositoryAdapter.PREFERENCE_NAME);
  }

  /** Called only by the one-time legacy migration. */
  public async importLegacyNumericIds(context: common.Context, identifiers: LegacyTaskIdentifier[]): Promise<void> {
    await this.initialize(context);
    await this.bindLegacyNumericIds(identifiers);
  }

  public async listTasks(): Promise<DDLItem[]> {
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskListViewModelJson());
    const result: DDLItem[] = [];
    for (let index = 0; index < tasks.length; index++) {
      const task: KmpTaskPayload = tasks[index];
      if (!task.isDeleted && await this.typeFor(task.uid) === DeadlineType.TASK) {
        result.push(await this.toDDLItem(task));
      }
    }
    return result;
  }

  public async findTask(id: number): Promise<DDLItem | null> {
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskListViewModelJson());
    for (let index = 0; index < tasks.length; index++) {
      const task: KmpTaskPayload = tasks[index];
      if (!task.isDeleted && await this.idFor(KmpTaskRepositoryAdapter.TASK_ID_PREFIX, task.uid) === id &&
        await this.typeFor(task.uid) === DeadlineType.TASK) {
        return this.toDDLItem(task);
      }
    }
    return null;
  }

  public async create(params: TaskCreateParams): Promise<number> {
    const now: string = new Date().toISOString();
    const state: TaskState = params.state ?? this.stateFromLegacyFlags(params.isCompleted, params.isArchived);
    const task: KmpTaskPayload = {
      uid: util.generateRandomUUID(true),
      title: params.name,
      note: params.note,
      startAt: this.blankToNull(params.startTime),
      dueAt: this.blankToNull(params.endTime),
      state: state,
      completedAt: this.blankToNull(params.completeTime),
      categoryUid: params.categoryUid ?? null,
      isStarred: params.isStared,
      calendarEventId: params.calendarEventId,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      subtasks: []
    };
    const updated: KmpTaskPayload[] = this.readTasks(this.persistence.taskCreateJson(JSON.stringify(task)));
    await this.markType(task.uid, DeadlineType.TASK);
    return this.idFor(KmpTaskRepositoryAdapter.TASK_ID_PREFIX, this.requireTask(updated, task.uid).uid);
  }

  public async legacyTaskIdForUid(uid: string): Promise<number> {
    return this.idFor(KmpTaskRepositoryAdapter.TASK_ID_PREFIX, uid);
  }

  public async markHabitUid(uid: string): Promise<void> {
    await this.markType(uid, DeadlineType.HABIT);
  }

  public async deleteHabitCarrierIfPresent(uid: string): Promise<boolean> {
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskListViewModelJson());
    for (let index = 0; index < tasks.length; index++) {
      const task: KmpTaskPayload = tasks[index];
      if (!task.isDeleted && task.uid === uid) {
        this.persistence.taskDeleteJson(uid, new Date().toISOString());
        await this.markHabitUid(uid);
        return true;
      }
    }
    return false;
  }

  public async taskUidForLegacyId(id: number): Promise<string | null> {
    const task: KmpTaskPayload | null = await this.findRawTaskByLegacyId(id, false);
    return task === null ? null : task.uid;
  }

  public async update(item: DDLItem): Promise<void> {
    const current: KmpTaskPayload = await this.requireTaskById(item.id);
    if (current.state !== item.state && this.hasActiveFocusTimer(current.uid)) {
      throw new Error('FOCUS_TIMER_REQUIRES_RESOLUTION');
    }
    const updatedAt: string = new Date().toISOString();
    const updated: KmpTaskPayload = {
      uid: current.uid,
      title: item.name,
      note: item.note,
      startAt: this.blankToNull(item.startTime),
      dueAt: this.blankToNull(item.endTime),
      state: item.state,
      completedAt: this.blankToNull(item.completeTime),
      categoryUid: item.categoryUid === undefined ? current.categoryUid : item.categoryUid,
      isStarred: item.isStared,
      calendarEventId: item.calendarEventId,
      createdAt: current.createdAt,
      updatedAt: updatedAt,
      isDeleted: false,
      subtasks: current.subtasks
    };
    this.persistence.taskUpdateJson(JSON.stringify(updated));
  }

  public async delete(id: number): Promise<boolean> {
    const task: KmpTaskPayload | null = await this.findRawTaskById(id);
    if (task === null) return false;
    if (this.hasActiveFocusTimer(task.uid)) {
      if (!await FocusChangeConfirmation.request(task.uid, false, true)) throw new Error('操作已取消或会话已变化');
      return true;
    }
    this.persistence.taskDeleteJson(task.uid, new Date().toISOString());
    return true;
  }

  public async applyAction(id: number, action: TaskStateAction): Promise<DDLItem | null> {
    const task: KmpTaskPayload | null = await this.findRawTaskById(id);
    if (task === null) return null;
    if (this.hasActiveFocusTimer(task.uid)) {
      if (!await FocusChangeConfirmation.request(task.uid, false, false, this.toKmpAction(action))) throw new Error('操作已取消或会话已变化');
      return this.toDDLItem(await this.requireTaskById(id));
    }
    const actionPayload: string = JSON.stringify({
      action: this.toKmpAction(action),
      occurredAt: new Date().toISOString()
    });
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskActionJson(task.uid, actionPayload));
    return this.toDDLItem(this.requireTask(tasks, task.uid));
  }

  private hasActiveFocusTimer(taskUid: string): boolean {
    const state: FocusTimerGuardStatePayload = JSON.parse(this.persistence.focusStateJson(taskUid));
    const bound: boolean = state.timer !== null && state.timer.taskUid === taskUid &&
      (state.timer.target === null || state.timer.target === undefined || state.timer.target.kind === 'TASK');
    return bound;
  }

  public async subtasksForTask(id: number): Promise<SubTask[] | null> {
    const task: KmpTaskPayload | null = await this.findRawTaskById(id);
    if (task === null) return null;
    const result: SubTask[] = [];
    for (let index = 0; index < task.subtasks.length; index++) {
      const subtask: KmpTaskSubtaskPayload = task.subtasks[index];
      if (!subtask.isDeleted) result.push(await this.toSubTask(id, subtask));
    }
    return result;
  }

  public async insertSubtask(taskId: number, content: string, sortOrder: number): Promise<number> {
    const task: KmpTaskPayload = await this.requireTaskById(taskId);
    const now: string = new Date().toISOString();
    const subtask: KmpTaskSubtaskPayload = {
      uid: util.generateRandomUUID(true),
      taskUid: task.uid,
      content: content,
      isCompleted: false,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      isDeleted: false
    };
    task.subtasks.push(subtask);
    task.updatedAt = now;
    this.persistence.taskUpdateJson(JSON.stringify(task));
    return this.idFor(KmpTaskRepositoryAdapter.SUBTASK_ID_PREFIX, subtask.uid);
  }

  public async toggleSubtask(subTaskId: number, isCompleted: boolean): Promise<boolean> {
    return this.updateSubtask(subTaskId, '', isCompleted, false);
  }

  public async deleteSubtask(subTaskId: number): Promise<boolean> {
    return this.updateSubtask(subTaskId, '', false, true);
  }

  public async updateSubtaskContent(subTaskId: number, content: string): Promise<boolean> {
    return this.updateSubtask(subTaskId, content, false, false, true);
  }

  private async updateSubtask(
    subTaskId: number,
    content: string,
    isCompleted: boolean,
    isDeleted: boolean,
    replaceContent: boolean = false
  ): Promise<boolean> {
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskListViewModelJson());
    for (let taskIndex = 0; taskIndex < tasks.length; taskIndex++) {
      const task: KmpTaskPayload = tasks[taskIndex];
      if (await this.typeFor(task.uid) !== DeadlineType.TASK) continue;
      for (let subtaskIndex = 0; subtaskIndex < task.subtasks.length; subtaskIndex++) {
        const subtask: KmpTaskSubtaskPayload = task.subtasks[subtaskIndex];
        if (await this.idFor(KmpTaskRepositoryAdapter.SUBTASK_ID_PREFIX, subtask.uid) !== subTaskId) continue;
        subtask.isCompleted = replaceContent ? subtask.isCompleted : isCompleted;
        subtask.isDeleted = isDeleted;
        if (replaceContent) subtask.content = content;
        subtask.updatedAt = new Date().toISOString();
        task.updatedAt = subtask.updatedAt;
        this.persistence.taskUpdateJson(JSON.stringify(task));
        return true;
      }
    }
    return false;
  }

  private async toDDLItem(task: KmpTaskPayload): Promise<DDLItem> {
    const state: TaskState = task.state;
    return {
      id: await this.idFor(KmpTaskRepositoryAdapter.TASK_ID_PREFIX, task.uid),
      name: task.title,
      startTime: task.startAt ?? '',
      endTime: task.dueAt ?? '',
      state: state,
      isCompleted: state === TaskState.COMPLETED || state === TaskState.ARCHIVED,
      completeTime: task.completedAt ?? '',
      note: task.note,
      isArchived: state === TaskState.ARCHIVED || state === TaskState.ABANDONED_ARCHIVED,
      isStared: task.isStarred,
      type: DeadlineType.TASK,
      habitCount: 0,
      habitTotalCount: 0,
      calendarEventId: task.calendarEventId,
      categoryUid: task.categoryUid,
      timeStamp: task.updatedAt,
      uid: task.uid,
      deleted: task.isDeleted,
      verTs: task.updatedAt,
      verCtr: 0,
      verDev: ''
    };
  }

  private async toSubTask(taskId: number, subtask: KmpTaskSubtaskPayload): Promise<SubTask> {
    return {
      id: await this.idFor(KmpTaskRepositoryAdapter.SUBTASK_ID_PREFIX, subtask.uid),
      ddlId: taskId,
      content: subtask.content,
      isCompleted: subtask.isCompleted,
      sortOrder: subtask.sortOrder,
      uid: subtask.uid,
      deleted: subtask.isDeleted,
      verTs: subtask.updatedAt,
      verCtr: 0,
      verDev: ''
    };
  }

  private readTasks(payload: string): KmpTaskPayload[] {
    const parsed: KmpTaskPayload[] = JSON.parse(payload) as KmpTaskPayload[];
    return parsed;
  }

  private requireTask(tasks: KmpTaskPayload[], uid: string): KmpTaskPayload {
    for (let index = 0; index < tasks.length; index++) {
      if (tasks[index].uid === uid) return tasks[index];
    }
    throw new Error('KMP task mutation returned no task for uid ' + uid);
  }

  private async requireTaskById(id: number): Promise<KmpTaskPayload> {
    const task: KmpTaskPayload | null = await this.findRawTaskById(id);
    if (task === null) throw new Error('KMP task not found for legacy id ' + id.toString());
    return task;
  }

  private async findRawTaskById(id: number): Promise<KmpTaskPayload | null> {
    return this.findRawTaskByLegacyId(id, true);
  }

  private async findRawTaskByLegacyId(id: number, tasksOnly: boolean): Promise<KmpTaskPayload | null> {
    const tasks: KmpTaskPayload[] = this.readTasks(this.persistence.taskListViewModelJson());
    for (let index = 0; index < tasks.length; index++) {
      const task: KmpTaskPayload = tasks[index];
      if (!task.isDeleted && (!tasksOnly || await this.typeFor(task.uid) === DeadlineType.TASK) &&
        await this.idFor(KmpTaskRepositoryAdapter.TASK_ID_PREFIX, task.uid) === id) return task;
    }
    return null;
  }

  private async bindLegacyNumericIds(identifiers: LegacyTaskIdentifier[]): Promise<void> {
    const store: preferences.Preferences = this.requireStore();
    let nextId: number = this.readStoredNumber(await store.get(KmpTaskRepositoryAdapter.NEXT_ID_KEY, KmpTaskRepositoryAdapter.FIRST_SYNTHETIC_ID));
    for (let itemIndex = 0; itemIndex < identifiers.length; itemIndex++) {
      const item: LegacyTaskIdentifier = identifiers[itemIndex];
      await store.put(KmpTaskRepositoryAdapter.TASK_ID_PREFIX + item.uid, item.id);
      await store.put(KmpTaskRepositoryAdapter.TYPE_PREFIX + item.uid, item.type);
      if (item.id >= nextId) nextId = item.id + 1;
      for (let subtaskIndex = 0; subtaskIndex < item.subtasks.length; subtaskIndex++) {
        const subtask: LegacySubtaskIdentifier = item.subtasks[subtaskIndex];
        if (subtask.uid.length > 0) {
          await store.put(KmpTaskRepositoryAdapter.SUBTASK_ID_PREFIX + subtask.uid, subtask.id);
          if (subtask.id >= nextId) nextId = subtask.id + 1;
        }
      }
    }
    await store.put(KmpTaskRepositoryAdapter.NEXT_ID_KEY, nextId);
    await store.flush();
  }

  private async idFor(prefix: string, uid: string): Promise<number> {
    const store: preferences.Preferences = this.requireStore();
    const key: string = prefix + uid;
    const stored: preferences.ValueType = await store.get(key, 0);
    if (typeof stored === 'number' && stored > 0) return stored;
    const next: preferences.ValueType = await store.get(KmpTaskRepositoryAdapter.NEXT_ID_KEY, KmpTaskRepositoryAdapter.FIRST_SYNTHETIC_ID);
    const id: number = this.readStoredNumber(next);
    await store.put(key, id);
    await store.put(KmpTaskRepositoryAdapter.NEXT_ID_KEY, id + 1);
    await store.flush();
    return id;
  }

  private async typeFor(uid: string): Promise<DeadlineType> {
    const stored: preferences.ValueType = await this.requireStore().get(KmpTaskRepositoryAdapter.TYPE_PREFIX + uid, DeadlineType.TASK);
    return stored === DeadlineType.HABIT ? DeadlineType.HABIT : DeadlineType.TASK;
  }

  private async markType(uid: string, type: DeadlineType): Promise<void> {
    const store: preferences.Preferences = this.requireStore();
    await store.put(KmpTaskRepositoryAdapter.TYPE_PREFIX + uid, type);
    await store.flush();
  }

  private requireStore(): preferences.Preferences {
    if (this.store === null) throw new Error('KMP task compatibility store is not initialized');
    return this.store;
  }

  private readStoredNumber(value: preferences.ValueType): number {
    return typeof value === 'number' && value > 0 ? value : KmpTaskRepositoryAdapter.FIRST_SYNTHETIC_ID;
  }

  private blankToNull(value: string): string | null {
    return value.length > 0 ? value : null;
  }

  private stateFromLegacyFlags(isCompleted: boolean, isArchived: boolean): TaskState {
    if (isArchived) return TaskState.ARCHIVED;
    if (isCompleted) return TaskState.COMPLETED;
    return TaskState.ACTIVE;
  }

  private toKmpAction(action: TaskStateAction): string {
    if (action === TaskStateAction.MARK_COMPLETE) return 'MARK_COMPLETE';
    if (action === TaskStateAction.MARK_ARCHIVE) return 'MARK_ARCHIVE';
    if (action === TaskStateAction.MARK_GIVE_UP) return 'MARK_GIVE_UP';
    if (action === TaskStateAction.RESTORE_ACTIVE) return 'RESTORE_ACTIVE';
    return 'UNARCHIVE';
  }
}
