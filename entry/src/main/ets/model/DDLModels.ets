import { TaskState, TaskStateAction, TaskStateMachine } from './TaskStateMachine';

// 对应 Kotlin: DeadlineType
export enum DeadlineType {
  TASK = 'task',
  HABIT = 'habit'
}

// 对应 Kotlin: HabitPeriod
export enum HabitPeriod {
  DAILY = 'DAILY',
  WEEKLY = 'WEEKLY',
  MONTHLY = 'MONTHLY',
  ONCE = 'ONCE',
  EBBINGHAUS = 'EBBINGHAUS'
}

// 对应 Kotlin: HabitGoalType
export enum HabitGoalType {
  PER_PERIOD = 'PER_PERIOD',
  TOTAL = 'TOTAL'
}

// 对应 Kotlin: HabitStatus
export enum HabitStatus {
  ACTIVE = 'ACTIVE',
  ARCHIVED = 'ARCHIVED'
}

// 对应 Kotlin: HabitRecordStatus
export enum HabitRecordStatus {
  COMPLETED = 'COMPLETED',
  SKIPPED = 'SKIPPED', // 假设你有这个，虽然原代码只看到 COMPLETED
  FAILED = 'FAILED'
}

// 对应 Kotlin: DDLItem
export interface DDLItem {
  id: number; // Long -> number
  name: string;
  startTime: string;
  endTime: string;
  state: TaskState;
  isCompleted: boolean;
  completeTime: string;
  note: string;
  isArchived: boolean;
  isStared: boolean;
  type: DeadlineType;
  habitCount: number;
  habitTotalCount: number;
  calendarEventId: number | null;
  timeStamp: string;

  // Sync fields
  uid?: string;
  deleted: boolean; // 0 or 1 in DB, boolean in model
  verTs: string;
  verCtr: number;
  verDev: string;
}

// 对应 Kotlin: Habit
export interface Habit {
  id: number;
  ddlId: number;
  name: string;
  description: string | null;
  color: number | null;
  iconKey: string | null;
  period: HabitPeriod;
  timesPerPeriod: number;
  goalType: HabitGoalType;
  totalTarget: number | null;
  createdAt: string;
  updatedAt: string;
  status: HabitStatus;
  sortOrder: number;
  alarmTime: string | null;
}

// 对应 Kotlin: HabitRecord
export interface HabitRecord {
  id: number;
  habitId: number;
  date: string; // LocalDate.toString() -> "YYYY-MM-DD"
  count: number;
  status: HabitRecordStatus;
  createdAt: string;
}

export interface SubTask {
  id: number;
  ddlId: number;      // 关联父任务
  content: string;    // 内容
  isCompleted: boolean;
  sortOrder: number;

  // Sync fields (为了同步，子任务也需要版本控制)
  uid?: string;
  deleted: boolean;
  verTs: string;
  verCtr: number;
  verDev: string;
}

// 对应 Kotlin: Ver (用于同步)
export interface Ver {
  ts: string;
  ctr: number;
  dev: string;
}

export function resolveTaskState(state: string | null | undefined, isCompleted: boolean, isArchived: boolean): TaskState {
  if (state === TaskState.ACTIVE ||
    state === TaskState.COMPLETED ||
    state === TaskState.ARCHIVED ||
    state === TaskState.ABANDONED ||
    state === TaskState.ABANDONED_ARCHIVED) {
    return state;
  }
  if (isArchived) return TaskState.ARCHIVED;
  if (isCompleted) return TaskState.COMPLETED;
  return TaskState.ACTIVE;
}

export function isTaskCompletedState(state: TaskState): boolean {
  return TaskStateMachine.isCompletedLike(state);
}

export function isTaskArchivedState(state: TaskState): boolean {
  return TaskStateMachine.isArchivedLike(state);
}

export function isTaskAbandonedState(state: TaskState): boolean {
  return TaskStateMachine.isAbandonedLike(state);
}

export function transitionDDLItem(item: DDLItem, action: TaskStateAction, actionTime: string): DDLItem {
  const nextState = TaskStateMachine.nextState(item.state, action);
  const nextCompleteTime = shouldResetCompletionTime(action)
    ? ''
    : shouldWriteCompletionTime(nextState)
      ? actionTime
      : item.completeTime;

  return {
    id: item.id,
    name: item.name,
    startTime: item.startTime,
    endTime: item.endTime,
    state: nextState,
    isCompleted: isTaskCompletedState(nextState),
    isArchived: isTaskArchivedState(nextState),
    completeTime: nextCompleteTime,
    note: item.note,
    isStared: item.isStared,
    type: item.type,
    habitCount: item.habitCount,
    habitTotalCount: item.habitTotalCount,
    calendarEventId: item.calendarEventId,
    timeStamp: item.timeStamp,
    uid: item.uid,
    deleted: item.deleted,
    verTs: item.verTs,
    verCtr: item.verCtr,
    verDev: item.verDev
  };
}

function shouldWriteCompletionTime(state: TaskState): boolean {
  return state === TaskState.COMPLETED || state === TaskState.ABANDONED;
}

function shouldResetCompletionTime(action: TaskStateAction): boolean {
  return action === TaskStateAction.RESTORE_ACTIVE;
}
