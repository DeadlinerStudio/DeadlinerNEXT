import {
  AIHabit,
  AITask,
  AIToolRequest,
  AIToolResult,
  ReadTasksArgs
} from '../../../ai/model/AIModels';
import {
  AdapterCreateHabitPayload,
  AdapterCreateTaskPayload,
  AdapterReadHabitsPayload,
  AdapterReadTasksPayload
} from '../../../ai/core/DeadlinerToolAdapter';
import {
  CreateHabitBatchItemArgs,
  CreateHabitToolArgs,
  CreateTaskBatchItemArgs,
  CreateTaskToolArgs
} from './AIPanelModels';

export function defaultToolReason(toolName: string): string {
  switch (toolName) {
    case 'read_tasks':
      return '为了回答你的问题，我需要查看你近期的任务。';
    case 'create_task':
      return '我准备帮你创建这个任务，请确认本地写入。';
    case 'update_deadline':
      return '我准备修改现有任务的截止时间，请确认本地写入。';
    case 'read_habits':
      return '为了避免重复创建，我需要先查看你现有的习惯。';
    case 'create_habit':
      return '我准备帮你创建这个习惯，请确认本地写入。';
    default:
      return '需要调用本地工具继续处理。';
  }
}

export function sanitizeReadTasksArgs(args: ReadTasksArgs, userQuery: string): ReadTasksArgs {
  const days = Math.max(1, Math.min(args.timeRangeDays ?? 7, 30));
  const limit = Math.max(1, Math.min(args.limit ?? 20, 50));
  const status = (args.status ?? 'OPEN').toUpperCase();
  const sort = (args.sort ?? 'DUE_ASC').toUpperCase();

  let kws = (args.keywords ?? [])
    .map(k => k.trim())
    .filter(k => k.length > 0)
    .slice(0, 3)
    .map(k => k.substring(0, 12));

  const q = userQuery.toLowerCase();
  kws = kws.filter(k => q.includes(k.toLowerCase()));

  const patterns = ['这周', '本周', '最近', '有哪些任务', '有什么任务', '任务列表', 'to do', 'todo', '待办', '待办事项', 'deadline', 'ddl'];
  const isGeneric = patterns.some(p => q.includes(p));
  const explicitSignals = ['关于', '相关', '的任务', '的ddl', '的待办', '项目', 'course', 'project'];
  const hasTopic = explicitSignals.some(s => q.includes(s));

  if (isGeneric && !hasTopic) {
    kws = [];
  }

  return { timeRangeDays: days, status, keywords: kws, limit, sort };
}

export function makeTaskKey(task: AITask): string {
  return `${task.name}#${task.dueTime || 'none'}`;
}

export function makeHabitKey(habit: AIHabit): string {
  return `${habit.name}#${habit.period}#${habit.timesPerPeriod}`;
}

export function toolDisplayTitle(toolName: string): string {
  switch (toolName) {
    case 'read_tasks':
      return '需要读取任务列表';
    case 'create_task':
      return '需要创建任务';
    case 'update_deadline':
      return '需要修改截止时间';
    case 'read_habits':
      return '需要读取习惯列表';
    case 'create_habit':
      return '需要创建习惯';
    default:
      return `需要执行工具 ${toolName}`;
  }
}

export function toolArgsSummary(req: AIToolRequest): string {
  if (req.tool === 'read_tasks') {
    const args = req.args as ReadTasksArgs;
    return `范围：未来 ${args.timeRangeDays || 7} 天 · 状态：${args.status || 'OPEN'}`;
  }
  if (req.tool === 'create_task') {
    const tasks = taskProposalsFromToolRequest(req);
    return `任务创建：${tasks.length} 条 · 模式：${req.executionMode || 'ASK_USER'}`;
  }
  if (req.tool === 'create_habit') {
    const habits = habitProposalsFromToolRequest(req);
    return `习惯创建：${habits.length} 条 · 模式：${req.executionMode || 'ASK_USER'}`;
  }
  return `工具：${req.tool} · 模式：${req.executionMode || 'ASK_USER'}`;
}

export function toolArgsDetail(req: AIToolRequest): string {
  if (req.tool === 'create_task') {
    const tasks = taskProposalsFromToolRequest(req);
    return tasks.map((task, index) => {
      const note = task.note && task.note.trim().length > 0 ? task.note : '无';
      const due = task.dueTime && task.dueTime.trim().length > 0 ? task.dueTime : '无';
      return `${index + 1}. 名称：${task.name}\n截止：${due}\n备注：${note}`;
    }).join('\n\n');
  }
  if (req.tool === 'create_habit') {
    const habits = habitProposalsFromToolRequest(req);
    return habits.map((habit, index) => {
      const total = habit.goalType === 'TOTAL' ? `，总目标：${habit.totalTarget ?? '缺失'}` : '';
      return `${index + 1}. 名称：${habit.name}\n周期：${habit.period}\n频次：${habit.timesPerPeriod}\n目标：${habit.goalType}${total}`;
    }).join('\n\n');
  }
  return '';
}

export function toolResultSummary(result: AIToolResult): string {
  if (result.tool === 'read_tasks') {
    const payload = result.payload as AdapterReadTasksPayload;
    return `已读取任务：${payload.summary.count} 条（逾期 ${payload.summary.overdue}）`;
  }
  if (result.tool === 'read_habits') {
    const payload = result.payload as AdapterReadHabitsPayload;
    return `已读取习惯：${payload.summary.count} 条`;
  }
  if (result.tool === 'create_task' || result.tool === 'update_deadline') {
    const payload = result.payload as AdapterCreateTaskPayload;
    if (result.tool === 'create_task') {
      const createdCount = payload.summary?.successCount ?? payload.createdTasks?.length ?? (payload.task ? 1 : 0);
      const failCount = payload.summary?.failCount ?? 0;
      if (createdCount > 1 || failCount > 0) {
        return `任务创建完成：成功 ${createdCount}，失败 ${failCount}`;
      }
      if (payload.task && payload.task.name) {
        return `已创建任务：${payload.task.name}`;
      }
    }
    if (result.tool === 'update_deadline' && payload.task && payload.task.name) {
      return `已更新截止时间：${payload.task.name}`;
    }
  }
  if (result.tool === 'create_habit') {
    const payload = result.payload as AdapterCreateHabitPayload;
    const createdCount = payload.summary?.successCount ?? payload.createdHabits?.length ?? (payload.habit ? 1 : 0);
    const failCount = payload.summary?.failCount ?? 0;
    if (createdCount > 1 || failCount > 0) {
      return `习惯创建完成：成功 ${createdCount}，失败 ${failCount}`;
    }
    if (payload.habit && payload.habit.name) {
      return `已创建习惯：${payload.habit.name}`;
    }
  }
  return `工具执行完成：${result.tool}`;
}

export function taskProposalsFromToolRequest(req: AIToolRequest): AITask[] {
  const args = req.args as CreateTaskToolArgs;
  const fromBatch = normalizeTaskToolArgs(args);
  if (fromBatch.length > 0) {
    return fromBatch
      .map((item) => {
        const normalized: AITask = {
          name: (item.name ?? '').trim(),
          dueTime: item.dueTime ?? item.due_time,
          note: item.note
        };
        return normalized;
      })
      .filter((item) => item.name.length > 0);
  }
  return [];
}

export function habitProposalsFromToolRequest(req: AIToolRequest): AIHabit[] {
  const args = req.args as CreateHabitToolArgs;
  const fromBatch = normalizeHabitToolArgs(args);
  if (fromBatch.length > 0) {
    return fromBatch
      .map((item) => {
        const normalized: AIHabit = {
          name: (item.name ?? '').trim(),
          period: (item.period ?? 'DAILY').toUpperCase(),
          timesPerPeriod: Math.max(1, item.timesPerPeriod ?? item.times_per_period ?? 1),
          goalType: (item.goalType ?? item.goal_type ?? 'PER_PERIOD').toUpperCase(),
          totalTarget: item.totalTarget ?? item.total_target
        };
        return normalized;
      })
      .filter((item) => item.name.length > 0);
  }
  return [];
}

export function normalizeTaskToolArgs(args: CreateTaskToolArgs): CreateTaskBatchItemArgs[] {
  const candidates: CreateTaskBatchItemArgs[] = [];
  if (args.tasks) {
    candidates.push(...args.tasks);
  }
  if (args.items) {
    candidates.push(...args.items);
  }
  if (args.task) {
    candidates.push(args.task);
  }
  if (candidates.length > 0) {
    return candidates;
  }
  const name = (args.name ?? '').trim();
  if (name.length === 0) {
    return [];
  }
  return [{
    name: name,
    dueTime: args.dueTime ?? args.due_time,
    note: args.note
  }];
}

export function normalizeHabitToolArgs(args: CreateHabitToolArgs): CreateHabitBatchItemArgs[] {
  const candidates: CreateHabitBatchItemArgs[] = [];
  if (args.habits) {
    candidates.push(...args.habits);
  }
  if (args.items) {
    candidates.push(...args.items);
  }
  if (args.habit) {
    candidates.push(args.habit);
  }
  if (candidates.length > 0) {
    return candidates;
  }
  const name = (args.name ?? '').trim();
  if (name.length === 0) {
    return [];
  }
  return [{
    name: name,
    period: args.period,
    timesPerPeriod: args.timesPerPeriod,
    times_per_period: args.times_per_period,
    goalType: args.goalType,
    goal_type: args.goal_type,
    totalTarget: args.totalTarget,
    total_target: args.total_target
  }];
}
