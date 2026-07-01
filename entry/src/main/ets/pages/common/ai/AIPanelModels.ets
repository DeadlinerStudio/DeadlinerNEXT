import util from '@ohos.util';
import {
  AIHabit,
  AITask,
  AIToolRequest,
  AIToolResult
} from '../../../ai/model/AIModels';

export enum DisplayItemType {
  UserQuery,
  AIChat,
  AIThinking,
  AITask,
  AIHabit,
  AIMemory,
  AIToolRequest,
  AIToolResult
}

@Observed
export class DisplayItem {
  id: string;
  type: DisplayItemType;
  text?: string;
  task?: AITask;
  habit?: AIHabit;
  toolReq?: AIToolRequest;
  toolRes?: AIToolResult;

  constructor(type: DisplayItemType, id?: string) {
    this.type = type;
    this.id = id || util.generateRandomUUID(true);
  }
}

export interface DisplayItemSnapshot {
  id: string;
  type: DisplayItemType;
  text?: string;
  task?: AITask;
  habit?: AIHabit;
  toolReq?: AIToolRequest;
  toolRes?: AIToolResult;
}

export interface AIWorkspaceSessionSnapshot {
  displayItems: DisplayItemSnapshot[];
  sessionSummary: string;
  addedTaskKeys: string[];
  addedHabitKeys: string[];
  taskProposalToolRequests: ProposalToolRequestLink[];
  habitProposalToolRequests: ProposalToolRequestLink[];
  lastSubmittedToolName: string;
  toolOriginalUserText: string;
  updatedAt: number;
}

export interface AIConversationHistoryRecord {
  id: string;
  title: string;
  preview: string;
  updatedAt: number;
  itemCount: number;
  displayItems: DisplayItemSnapshot[];
}

export function snapshotDisplayItem(item: DisplayItem): DisplayItemSnapshot {
  return {
    id: item.id,
    type: item.type,
    text: item.text,
    task: item.task,
    habit: item.habit,
    toolReq: item.toolReq,
    toolRes: item.toolRes
  };
}

export function restoreDisplayItem(snapshot: DisplayItemSnapshot): DisplayItem {
  const item = new DisplayItem(snapshot.type, snapshot.id);
  item.text = snapshot.text;
  item.task = snapshot.task;
  item.habit = snapshot.habit;
  item.toolReq = snapshot.toolReq;
  item.toolRes = snapshot.toolRes;
  return item;
}

export function restoreDisplayItems(snapshots: DisplayItemSnapshot[]): DisplayItem[] {
  return snapshots.map((snapshot) => restoreDisplayItem(snapshot));
}

export interface CreateTaskToolArgs {
  name?: string;
  dueTime?: string;
  due_time?: string;
  note?: string;
  task?: CreateTaskBatchItemArgs;
  tasks?: CreateTaskBatchItemArgs[];
  items?: CreateTaskBatchItemArgs[];
}

export interface CreateTaskBatchItemArgs {
  name?: string;
  dueTime?: string;
  due_time?: string;
  note?: string;
}

export interface CreateHabitToolArgs {
  name?: string;
  period?: string;
  timesPerPeriod?: number;
  times_per_period?: number;
  goalType?: string;
  goal_type?: string;
  totalTarget?: number;
  total_target?: number;
  habit?: CreateHabitBatchItemArgs;
  habits?: CreateHabitBatchItemArgs[];
  items?: CreateHabitBatchItemArgs[];
}

export interface CreateHabitBatchItemArgs {
  name?: string;
  period?: string;
  timesPerPeriod?: number;
  times_per_period?: number;
  goalType?: string;
  goal_type?: string;
  totalTarget?: number;
  total_target?: number;
}

export class ProposalToolRequestLink {
  key: string;
  request: AIToolRequest;

  constructor(key: string, request: AIToolRequest) {
    this.key = key;
    this.request = request;
  }
}
