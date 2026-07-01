import { DDLInsertParams } from '../../common/data/DatabaseHelper';
import { HabitRepository } from '../../common/repository/HabitRepository';
import { TaskRepository } from '../../common/repository/TaskRepository';
import {
  DeadlineType,
  DDLItem,
  HabitGoalType,
  HabitPeriod,
  HabitStatus,
  isTaskCompletedState
} from '../../model/DDLModels';
import { TaskState } from '../../model/TaskStateMachine';
import { DateTimeUtils } from '../../utils/DateTimeUtils';

export interface AdapterToolCall {
  id: string;
  toolName: string;
  argsJson: string;
}

export interface AdapterErrorPayload {
  ok: boolean;
  errorCode: string;
  message: string;
}

export interface AdapterReadTaskItem {
  id: number;
  name: string;
  due: string;
  status: string;
  notePreview: string;
}

export interface AdapterReadTaskSummary {
  count: number;
  dueSoon24h: number;
  overdue: number;
}

export interface AdapterReadTasksPayload {
  tasks: AdapterReadTaskItem[];
  summary: AdapterReadTaskSummary;
}

export interface AdapterTaskPayload {
  id: number;
  name: string;
  due: string;
}

export interface AdapterCreateTaskPayload {
  ok: boolean;
  task: AdapterTaskPayload | null;
  createdTasks: AdapterTaskPayload[];
  summary: AdapterBatchSummary;
  items: AdapterBatchItemResult<AdapterTaskPayload>[];
}

export interface AdapterReadHabitItem {
  id: number;
  name: string;
  period: string;
  timesPerPeriod: number;
  goalType: string;
  totalTarget: number | null;
}

export interface AdapterReadHabitsSummary {
  count: number;
}

export interface AdapterReadHabitsPayload {
  habits: AdapterReadHabitItem[];
  summary: AdapterReadHabitsSummary;
}

export interface AdapterHabitPayload {
  id: number;
  name: string;
  period: string;
  timesPerPeriod: number;
  goalType: string;
  totalTarget: number | null;
}

export interface AdapterCreateHabitPayload {
  ok: boolean;
  habit: AdapterHabitPayload | null;
  createdHabits: AdapterHabitPayload[];
  summary: AdapterBatchSummary;
  items: AdapterBatchItemResult<AdapterHabitPayload>[];
}

export interface AdapterBatchSummary {
  total: number;
  successCount: number;
  failCount: number;
}

export interface AdapterBatchItemResult<TPayload> {
  ok: boolean;
  itemIndex: number;
  errorCode?: string;
  message?: string;
  data?: TPayload;
}

export interface AdapterToolExecution {
  resultJson: string;
  payload:
    AdapterErrorPayload |
    AdapterReadTasksPayload |
    AdapterCreateTaskPayload |
    AdapterReadHabitsPayload |
    AdapterCreateHabitPayload;
}

interface ReadTasksArgs {
  timeRangeDays?: number;
  status?: string;
  keywords?: string[];
  limit?: number;
  sort?: string;
}

interface ReadHabitsArgs {
  keywords?: string[];
}

interface CreateTaskArgs {
  name?: string;
  dueTime?: string;
  due_time?: string;
  note?: string;
  tasks?: CreateTaskItemArgs[];
}

interface CreateTaskItemArgs {
  name?: string;
  dueTime?: string;
  due_time?: string;
  note?: string;
}

interface ResolveCreateTaskItemsResult {
  ok: boolean;
  isBatch: boolean;
  items: CreateTaskItemArgs[];
  message?: string;
}

interface ResolveCreateHabitItemsResult {
  ok: boolean;
  isBatch: boolean;
  items: CreateHabitItemArgs[];
  message?: string;
}

interface ValidatedCreateTaskItem {
  name: string;
  dueDate: Date;
  note: string;
}

interface ValidateCreateTaskItemResult {
  ok: boolean;
  message?: string;
  normalized?: ValidatedCreateTaskItem;
}

interface UpdateDeadlineArgs {
  taskId?: number | string;
  task_id?: number | string;
  newDueTime?: string;
  new_due_time?: string;
}

interface CreateHabitArgs {
  name?: string;
  period?: string;
  timesPerPeriod?: number;
  times_per_period?: number;
  goalType?: string;
  goal_type?: string;
  totalTarget?: number;
  total_target?: number;
  habits?: CreateHabitItemArgs[];
}

interface CreateHabitItemArgs {
  name?: string;
  period?: string;
  timesPerPeriod?: number;
  times_per_period?: number;
  goalType?: string;
  goal_type?: string;
  totalTarget?: number;
  total_target?: number;
}

interface ValidatedCreateHabitItem {
  name: string;
  period: HabitPeriod;
  timesPerPeriod: number;
  goalType: HabitGoalType;
  totalTarget: number | null;
}

interface ValidateCreateHabitItemResult {
  ok: boolean;
  message?: string;
  normalized?: ValidatedCreateHabitItem;
}

class CreateTaskBatchSource {
  key: string;
  value: CreateTaskItemArgs[] | undefined;

  constructor(key: string, value: CreateTaskItemArgs[] | undefined) {
    this.key = key;
    this.value = value;
  }
}

class CreateHabitBatchSource {
  key: string;
  value: CreateHabitItemArgs[] | undefined;

  constructor(key: string, value: CreateHabitItemArgs[] | undefined) {
    this.key = key;
    this.value = value;
  }
}

class EmptyArgs {
}

export class DeadlinerToolAdapter {
  private static instance: DeadlinerToolAdapter;

  public static getInstance(): DeadlinerToolAdapter {
    if (!DeadlinerToolAdapter.instance) {
      DeadlinerToolAdapter.instance = new DeadlinerToolAdapter();
    }
    return DeadlinerToolAdapter.instance;
  }

  public async execute(call: AdapterToolCall): Promise<AdapterToolExecution> {
    console.info(`[DeadlinerToolAdapter] execute tool=${call.toolName} id=${call.id} args=${call.argsJson}`);
    const args = this.parseArgs(call.argsJson);
    switch (call.toolName) {
      case 'read_tasks':
        return this.executeReadTasks(args as ReadTasksArgs);
      case 'create_task':
        return this.executeCreateTask(args as CreateTaskArgs);
      case 'update_deadline':
        return this.executeUpdateDeadline(args as UpdateDeadlineArgs);
      case 'read_habits':
        return this.executeReadHabits(args as ReadHabitsArgs);
      case 'create_habit':
        return this.executeCreateHabit(args as CreateHabitArgs);
      default:
        return this.fail('UNSUPPORTED_TOOL', `暂不支持工具 ${call.toolName}`);
    }
  }

  private parseArgs(argsJson: string): Object {
    if (!argsJson || !argsJson.trim()) {
      return new EmptyArgs();
    }
    const parsed: Object = JSON.parse(argsJson) as Object;
    return parsed;
  }

  private async executeReadTasks(rawArgs: ReadTasksArgs): Promise<AdapterToolExecution> {
    const args: ReadTasksArgs = {
      timeRangeDays: this.clampInt(rawArgs.timeRangeDays, 1, 365, 7),
      status: (rawArgs.status ?? 'OPEN').toUpperCase(),
      keywords: (rawArgs.keywords ?? []).slice(0, 3),
      limit: this.clampInt(rawArgs.limit, 1, 50, 20),
      sort: (rawArgs.sort ?? 'DUE_ASC').toUpperCase()
    };

    const allTasks = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);
    const now = Date.now();
    const rangeMs = (args.timeRangeDays ?? 7) * 24 * 60 * 60 * 1000;
    const keywords = (args.keywords ?? []).map((item) => item.toLowerCase());

    let tasks = allTasks.filter((item) => {
      const dueDate = this.parseTaskDate(item.endTime);
      if (!dueDate) {
        return false;
      }

      const status = this.toTaskStatus(item);
      if (args.status === 'OPEN' && status !== 'OPEN') {
        return false;
      }
      if (args.status === 'DONE' && status !== 'DONE') {
        return false;
      }

      if (keywords.length > 0) {
        const haystack = `${item.name} ${item.note}`.toLowerCase();
        const matched = keywords.some((keyword) => haystack.includes(keyword));
        if (!matched) {
          return false;
        }
      }

      if (status === 'OPEN') {
        return dueDate.getTime() <= now + rangeMs;
      }
      return true;
    });

    tasks = tasks.sort((lhs, rhs) => {
      if (args.sort === 'UPDATED_DESC') {
        return rhs.timeStamp.localeCompare(lhs.timeStamp);
      }
      return lhs.endTime.localeCompare(rhs.endTime);
    }).slice(0, args.limit ?? 20);

    const items: AdapterReadTaskItem[] = [];
    let dueSoon24h = 0;
    let overdue = 0;

    for (const item of tasks) {
      const taskItem: AdapterReadTaskItem = {
        id: item.id,
        name: item.name,
        due: this.toToolDue(item.endTime),
        status: this.toTaskStatus(item),
        notePreview: item.note.length > 40 ? item.note.substring(0, 40) : item.note
      };
      items.push(taskItem);

      const dueDate = this.parseTaskDate(item.endTime);
      if (dueDate && taskItem.status === 'OPEN') {
        if (dueDate.getTime() < now) {
          overdue += 1;
        } else if (dueDate.getTime() <= now + 24 * 60 * 60 * 1000) {
          dueSoon24h += 1;
        }
      }
    }

    const summary: AdapterReadTaskSummary = {
      count: items.length,
      dueSoon24h: dueSoon24h,
      overdue: overdue
    };

    const payload: AdapterReadTasksPayload = {
      tasks: items,
      summary: summary
    };

    return this.success(payload);
  }

  private async executeCreateTask(rawArgs: CreateTaskArgs): Promise<AdapterToolExecution> {
    const resolveResult = this.resolveCreateTaskItems(rawArgs);
    if (!resolveResult.ok) {
      return this.fail('INVALID_ARGS', resolveResult.message ?? 'create_task 参数错误');
    }

    const items = resolveResult.items;
    const createdTasks: AdapterTaskPayload[] = [];
    const batchItems: AdapterBatchItemResult<AdapterTaskPayload>[] = [];

    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const validation = this.validateCreateTaskItem(item);
      if (!validation.ok || !validation.normalized) {
        if (!resolveResult.isBatch) {
          return this.fail('INVALID_ARGS', validation.message ?? 'create_task 参数错误');
        }
        batchItems.push({
          ok: false,
          itemIndex: index,
          errorCode: 'INVALID_ARGS',
          message: validation.message ?? '任务参数错误'
        });
        continue;
      }

      const normalized = validation.normalized;
      const params: DDLInsertParams = {
        name: normalized.name,
        startTime: DateTimeUtils.toLocalISOString(new Date()),
        endTime: DateTimeUtils.toLocalISOString(normalized.dueDate),
        state: TaskState.ACTIVE,
        isCompleted: false,
        completeTime: '',
        note: normalized.note,
        isArchived: false,
        isStared: false,
        type: DeadlineType.TASK,
        calendarEventId: null
      };

      try {
        const taskId = await TaskRepository.getInstance().insertDDL(params);
        console.info(`[DeadlinerToolAdapter] create_task inserted id=${taskId} name=${normalized.name}`);
        const task: AdapterTaskPayload = {
          id: taskId,
          name: normalized.name,
          due: this.toToolDue(params.endTime)
        };
        createdTasks.push(task);
        batchItems.push({
          ok: true,
          itemIndex: index,
          data: task
        });
      } catch (err) {
        console.error(`[DeadlinerToolAdapter] create_task failed index=${index} err=${JSON.stringify(err)}`);
        batchItems.push({
          ok: false,
          itemIndex: index,
          errorCode: 'CREATE_FAILED',
          message: '任务创建失败'
        });
      }
    }

    const summary = this.buildBatchSummary(items.length, createdTasks.length);
    const payload: AdapterCreateTaskPayload = {
      ok: summary.failCount === 0,
      task: createdTasks.length > 0 ? createdTasks[0] : null,
      createdTasks: createdTasks,
      summary: summary,
      items: batchItems
    };
    return this.success(payload);
  }

  private async executeUpdateDeadline(rawArgs: UpdateDeadlineArgs): Promise<AdapterToolExecution> {
    const taskIdValue = rawArgs.taskId ?? rawArgs.task_id;
    const newDueTime = (rawArgs.newDueTime ?? rawArgs.new_due_time ?? '').trim();

    if (taskIdValue === undefined || taskIdValue === null || `${taskIdValue}`.trim().length === 0) {
      return this.fail('INVALID_ARGS', 'update_deadline 缺少 taskId');
    }
    if (!newDueTime) {
      return this.fail('INVALID_ARGS', 'update_deadline 缺少 newDueTime');
    }

    const taskId = Number(taskIdValue);
    if (Number.isNaN(taskId)) {
      return this.fail('INVALID_ARGS', 'taskId 必须是数字');
    }

    const task = await TaskRepository.getInstance().getDDLById(taskId);
    if (!task) {
      return this.fail('NOT_FOUND', `未找到任务 ${taskId}`);
    }

    const dueDate = DateTimeUtils.parseDateString(newDueTime);
    if (!dueDate) {
      return this.fail('INVALID_ARGS', 'newDueTime 格式必须为 YYYY-MM-DD HH:mm');
    }

    const updated: DDLItem = this.copyTaskWithNewEndTime(task, DateTimeUtils.toLocalISOString(dueDate));
    await TaskRepository.getInstance().updateDDL(updated);
    console.info(`[DeadlinerToolAdapter] update_deadline updated id=${taskId} due=${newDueTime}`);

    const taskPayload: AdapterTaskPayload = {
      id: updated.id,
      name: updated.name,
      due: this.toToolDue(updated.endTime)
    };
    const payload: AdapterCreateTaskPayload = {
      ok: true,
      task: taskPayload,
      createdTasks: [taskPayload],
      summary: this.buildBatchSummary(1, 1),
      items: [{
        ok: true,
        itemIndex: 0,
        data: taskPayload
      }]
    };
    return this.success(payload);
  }

  private async executeReadHabits(rawArgs: ReadHabitsArgs): Promise<AdapterToolExecution> {
    const keywords = (rawArgs.keywords ?? []).slice(0, 3).map((item) => item.toLowerCase());
    let habits = await HabitRepository.getInstance().getAllHabits();
    habits = habits.filter((habit) => habit.status === HabitStatus.ACTIVE);

    if (keywords.length > 0) {
      habits = habits.filter((habit) => {
        const haystack = `${habit.name} ${habit.description ?? ''}`.toLowerCase();
        return keywords.some((keyword) => haystack.includes(keyword));
      });
    }

    const items: AdapterReadHabitItem[] = [];
    for (const habit of habits) {
      const item: AdapterReadHabitItem = {
        id: habit.id,
        name: habit.name,
        period: habit.period,
        timesPerPeriod: habit.timesPerPeriod,
        goalType: habit.goalType,
        totalTarget: habit.totalTarget
      };
      items.push(item);
    }

    const summary: AdapterReadHabitsSummary = {
      count: items.length
    };
    const payload: AdapterReadHabitsPayload = {
      habits: items,
      summary: summary
    };
    return this.success(payload);
  }

  private async executeCreateHabit(rawArgs: CreateHabitArgs): Promise<AdapterToolExecution> {
    const resolveResult = this.resolveCreateHabitItems(rawArgs);
    if (!resolveResult.ok) {
      return this.fail('INVALID_ARGS', resolveResult.message ?? 'create_habit 参数错误');
    }

    const items = resolveResult.items;
    const createdHabits: AdapterHabitPayload[] = [];
    const batchItems: AdapterBatchItemResult<AdapterHabitPayload>[] = [];

    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const validation = this.validateCreateHabitItem(item);
      if (!validation.ok || !validation.normalized) {
        if (!resolveResult.isBatch) {
          return this.fail('INVALID_ARGS', validation.message ?? 'create_habit 参数错误');
        }
        batchItems.push({
          ok: false,
          itemIndex: index,
          errorCode: 'INVALID_ARGS',
          message: validation.message ?? '习惯参数错误'
        });
        continue;
      }

      const normalized = validation.normalized;
      try {
        const ddlParams: DDLInsertParams = {
          name: normalized.name,
          startTime: DateTimeUtils.toLocalISOString(new Date()),
          endTime: DateTimeUtils.toLocalISOString(new Date()),
          state: TaskState.ACTIVE,
          isCompleted: false,
          completeTime: '',
          note: '',
          isArchived: false,
          isStared: false,
          type: DeadlineType.HABIT,
          calendarEventId: null
        };
        const ddlId = await TaskRepository.getInstance().insertDDL(ddlParams);

        const habitId = await HabitRepository.getInstance().createHabitForDdl(
          ddlId,
          normalized.name,
          normalized.period,
          normalized.timesPerPeriod,
          normalized.goalType,
          normalized.totalTarget,
          '',
          null,
          null,
          0,
          null
        );
        console.info(`[DeadlinerToolAdapter] create_habit inserted id=${habitId} name=${normalized.name} ddlId=${ddlId}`);

        const habit: AdapterHabitPayload = {
          id: habitId,
          name: normalized.name,
          period: normalized.period,
          timesPerPeriod: normalized.timesPerPeriod,
          goalType: normalized.goalType,
          totalTarget: normalized.totalTarget
        };
        createdHabits.push(habit);
        batchItems.push({
          ok: true,
          itemIndex: index,
          data: habit
        });
      } catch (err) {
        console.error(`[DeadlinerToolAdapter] create_habit failed index=${index} err=${JSON.stringify(err)}`);
        batchItems.push({
          ok: false,
          itemIndex: index,
          errorCode: 'CREATE_FAILED',
          message: '习惯创建失败'
        });
      }
    }

    const summary = this.buildBatchSummary(items.length, createdHabits.length);
    const payload: AdapterCreateHabitPayload = {
      ok: summary.failCount === 0,
      habit: createdHabits.length > 0 ? createdHabits[0] : null,
      createdHabits: createdHabits,
      summary: summary,
      items: batchItems
    };
    return this.success(payload);
  }

  private resolveCreateTaskItems(rawArgs: CreateTaskArgs): ResolveCreateTaskItemsResult {
    const batchSources: CreateTaskBatchSource[] = [
      new CreateTaskBatchSource('tasks', rawArgs.tasks)
    ];
    for (const source of batchSources) {
      if (source.value !== undefined) {
        if (!Array.isArray(source.value) || source.value.length === 0) {
          return { ok: false, isBatch: true, items: [], message: `create_task 的 ${source.key} 不能为空数组` };
        }
        return { ok: true, isBatch: true, items: source.value };
      }
    }
    return { ok: true, isBatch: false, items: [rawArgs] };
  }

  private resolveCreateHabitItems(rawArgs: CreateHabitArgs): ResolveCreateHabitItemsResult {
    const batchSources: CreateHabitBatchSource[] = [
      new CreateHabitBatchSource('habits', rawArgs.habits)
    ];
    for (const source of batchSources) {
      if (source.value !== undefined) {
        if (!Array.isArray(source.value) || source.value.length === 0) {
          return { ok: false, isBatch: true, items: [], message: `create_habit 的 ${source.key} 不能为空数组` };
        }
        return { ok: true, isBatch: true, items: source.value };
      }
    }
    return { ok: true, isBatch: false, items: [rawArgs] };
  }

  private validateCreateTaskItem(rawArgs: CreateTaskItemArgs): ValidateCreateTaskItemResult {
    const name = (rawArgs.name ?? '').trim();
    const dueTime = (rawArgs.dueTime ?? rawArgs.due_time ?? '').trim();
    if (!name) {
      return { ok: false, message: 'create_task 缺少 name' };
    }
    if (!dueTime) {
      return { ok: false, message: 'create_task 缺少 dueTime' };
    }
    const dueDate = DateTimeUtils.parseDateString(dueTime);
    if (!dueDate) {
      return { ok: false, message: 'dueTime 格式必须为 YYYY-MM-DD HH:mm' };
    }
    return {
      ok: true,
      normalized: {
        name: name,
        dueDate: dueDate,
        note: rawArgs.note ?? ''
      }
    };
  }

  private validateCreateHabitItem(rawArgs: CreateHabitItemArgs): ValidateCreateHabitItemResult {
    const name = (rawArgs.name ?? '').trim();
    if (!name) {
      return { ok: false, message: 'create_habit 缺少 name' };
    }

    const periodRaw = (rawArgs.period ?? 'DAILY').toUpperCase();
    const goalTypeRaw = (rawArgs.goalType ?? rawArgs.goal_type ?? 'PER_PERIOD').toUpperCase();
    const timesPerPeriod = this.clampInt(rawArgs.timesPerPeriod ?? rawArgs.times_per_period, 1, 365, 1);
    const totalTarget = rawArgs.totalTarget ?? rawArgs.total_target ?? null;

    const period = this.toHabitPeriod(periodRaw);
    if (!period) {
      return { ok: false, message: `不支持的 habit period: ${periodRaw}` };
    }
    const goalType = this.toHabitGoalType(goalTypeRaw);
    if (!goalType) {
      return { ok: false, message: `不支持的 habit goalType: ${goalTypeRaw}` };
    }
    if (goalType === HabitGoalType.TOTAL && (totalTarget === null || totalTarget === undefined || totalTarget < 1)) {
      return { ok: false, message: 'TOTAL 习惯必须提供 totalTarget' };
    }

    return {
      ok: true,
      normalized: {
        name: name,
        period: period,
        timesPerPeriod: timesPerPeriod,
        goalType: goalType,
        totalTarget: totalTarget
      }
    };
  }

  private buildBatchSummary(total: number, successCount: number): AdapterBatchSummary {
    return {
      total: total,
      successCount: successCount,
      failCount: Math.max(0, total - successCount)
    };
  }

  private copyTaskWithNewEndTime(task: DDLItem, endTime: string): DDLItem {
    return {
      id: task.id,
      name: task.name,
      startTime: task.startTime,
      endTime: endTime,
      state: task.state,
      isCompleted: task.isCompleted,
      completeTime: task.completeTime,
      note: task.note,
      isArchived: task.isArchived,
      isStared: task.isStared,
      type: task.type,
      habitCount: task.habitCount,
      habitTotalCount: task.habitTotalCount,
      calendarEventId: task.calendarEventId,
      timeStamp: task.timeStamp,
      uid: task.uid,
      deleted: task.deleted,
      verTs: task.verTs,
      verCtr: task.verCtr,
      verDev: task.verDev
    };
  }

  private toTaskStatus(item: DDLItem): string {
    return isTaskCompletedState(item.state) ? 'DONE' : 'OPEN';
  }

  private toToolDue(rawValue: string): string {
    if (!rawValue) {
      return '';
    }
    const parsed = this.parseTaskDate(rawValue);
    return parsed ? parsed.toISOString() : rawValue;
  }

  private parseTaskDate(rawValue: string): Date | null {
    if (!rawValue) {
      return null;
    }
    return DateTimeUtils.parseDateString(rawValue) ?? new Date(rawValue);
  }

  private toHabitPeriod(value: string): HabitPeriod | null {
    switch (value) {
      case 'DAILY':
        return HabitPeriod.DAILY;
      case 'WEEKLY':
        return HabitPeriod.WEEKLY;
      case 'MONTHLY':
        return HabitPeriod.MONTHLY;
      case 'ONCE':
        return HabitPeriod.ONCE;
      case 'EBBINGHAUS':
        return HabitPeriod.EBBINGHAUS;
      default:
        return null;
    }
  }

  private toHabitGoalType(value: string): HabitGoalType | null {
    switch (value) {
      case 'PER_PERIOD':
        return HabitGoalType.PER_PERIOD;
      case 'TOTAL':
        return HabitGoalType.TOTAL;
      default:
        return null;
    }
  }

  private clampInt(value: number | undefined, min: number, max: number, fallback: number): number {
    if (value === undefined || value === null || Number.isNaN(Number(value))) {
      return fallback;
    }
    const normalized = Math.round(Number(value));
    return Math.min(max, Math.max(min, normalized));
  }

  private success(
    payload: AdapterReadTasksPayload | AdapterCreateTaskPayload | AdapterReadHabitsPayload | AdapterCreateHabitPayload
  ): AdapterToolExecution {
    return {
      resultJson: JSON.stringify(payload),
      payload: payload
    };
  }

  private fail(errorCode: string, message: string): AdapterToolExecution {
    const payload: AdapterErrorPayload = {
      ok: false,
      errorCode: errorCode,
      message: message
    };
    return {
      resultJson: JSON.stringify(payload),
      payload: payload
    };
  }
}
