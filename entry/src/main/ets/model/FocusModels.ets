export interface FocusTargetPayload { kind: string; uid: string; }
export interface FocusHabitRecordContextPayload {
  habitUid: string;
  name: string;
  occurredOn: string;
  trackingMode: string;
  unit: string | null;
  completedCount: number;
  targetCount: number;
  canRecord: boolean;
  habitUpdatedAt: string;
}
export interface FocusSessionPayload {
  target?: FocusTargetPayload | null;
  habitOccurredOn?: string | null;
  habitRecordedAmount?: number | null;
  uid: string;
  taskUid: string;
  taskTitleSnapshot: string;
  mode: string;
  plannedDurationSeconds: number | null;
  startedAt: string;
  endedAt: string;
  durationSeconds: number;
  completionKind: string;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

export interface FocusTimerSnapshotPayload {
  target: FocusTargetPayload | null;
  habitOccurredOn: string | null;
  canFinishAndRecord: boolean;
  habitRecordContext: FocusHabitRecordContextPayload | null;
  sessionUid: string;
  taskUid: string;
  taskTitle: string;
  mode: string;
  state: string;
  elapsedSeconds: number;
  remainingSeconds: number | null;
  plannedDurationSeconds: number | null;
  canPause: boolean;
  canResume: boolean;
  canFinish: boolean;
  canFinishAndComplete: boolean;
  warning: string | null;
}

export interface FocusTimerUiStatePayload {
  selectedTarget: FocusTargetPayload | null;
  habitRecordContext: FocusHabitRecordContextPayload | null;
  timer: FocusTimerSnapshotPayload | null;
  todayDurationSeconds: number;
  todaySessionCount: number;
  recentSessions: FocusSessionPayload[];
  selectedTaskUid: string | null;
  selectedTaskTitle: string | null;
  selectedTaskTodayDurationSeconds: number;
  selectedTaskTotalDurationSeconds: number;
  selectedTaskRecentSessions: FocusSessionPayload[];
  lastCompletedSession: FocusSessionPayload | null;
  lastCompletedTaskState?: string | null;
  canCompleteLastTask?: boolean;
  lastOutcome: string | null;
  warning: string | null;
  isLoading: boolean;
  isBusy: boolean;
  error: string | null;
}
