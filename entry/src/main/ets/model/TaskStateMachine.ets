export enum TaskState {
  ACTIVE = 'active',
  COMPLETED = 'completed',
  ARCHIVED = 'archived',
  ABANDONED = 'abandoned',
  ABANDONED_ARCHIVED = 'abandonedArchived'
}

export enum TaskStateAction {
  MARK_COMPLETE = 'markComplete',
  MARK_ARCHIVE = 'markArchive',
  MARK_GIVE_UP = 'markGiveUp',
  RESTORE_ACTIVE = 'restoreActive',
  UNARCHIVE = 'unarchive'
}

export class TaskStateMachine {
  static nextState(from: TaskState, action: TaskStateAction): TaskState {
    switch (from) {
      case TaskState.ACTIVE:
        if (action === TaskStateAction.MARK_COMPLETE) return TaskState.COMPLETED;
        if (action === TaskStateAction.MARK_GIVE_UP) return TaskState.ABANDONED;
        break;
      case TaskState.COMPLETED:
        if (action === TaskStateAction.MARK_ARCHIVE) return TaskState.ARCHIVED;
        if (action === TaskStateAction.RESTORE_ACTIVE) return TaskState.ACTIVE;
        break;
      case TaskState.ABANDONED:
        if (action === TaskStateAction.MARK_ARCHIVE) return TaskState.ABANDONED_ARCHIVED;
        if (action === TaskStateAction.RESTORE_ACTIVE) return TaskState.ACTIVE;
        break;
      case TaskState.ARCHIVED:
        if (action === TaskStateAction.UNARCHIVE) return TaskState.COMPLETED;
        break;
      case TaskState.ABANDONED_ARCHIVED:
        if (action === TaskStateAction.UNARCHIVE) return TaskState.ABANDONED;
        break;
      default:
        break;
    }

    throw new Error(`[TaskStateMachine] Illegal transition: ${from} --${action}--> ?`);
  }

  static requiresConfirmation(action: TaskStateAction): boolean {
    return action === TaskStateAction.MARK_GIVE_UP;
  }

  static isVisibleInMainList(state: TaskState): boolean {
    return state === TaskState.ACTIVE || state === TaskState.COMPLETED || state === TaskState.ABANDONED;
  }

  static isVisibleInArchiveList(state: TaskState): boolean {
    return state === TaskState.ARCHIVED || state === TaskState.ABANDONED_ARCHIVED;
  }

  static isCompletedLike(state: TaskState): boolean {
    return state === TaskState.COMPLETED || state === TaskState.ARCHIVED;
  }

  static isArchivedLike(state: TaskState): boolean {
    return state === TaskState.ARCHIVED || state === TaskState.ABANDONED_ARCHIVED;
  }

  static isAbandonedLike(state: TaskState): boolean {
    return state === TaskState.ABANDONED || state === TaskState.ABANDONED_ARCHIVED;
  }

  static archiveBadgeText(state: TaskState): string {
    if (state === TaskState.ABANDONED_ARCHIVED) {
      return '放弃归档';
    }
    if (state === TaskState.ARCHIVED) {
      return '完成归档';
    }
    return '';
  }
}
