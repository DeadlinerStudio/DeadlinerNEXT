import { DDLItem } from '../../model/DDLModels';
import { DDLStatus } from '../../model/DDLStatus';
import { TaskState } from '../../model/TaskStateMachine';
import { DeadlineSemanticStatus } from './SemanticContract';

export class DeadlineStatusResolver {
  private static readonly NEAR_DUE_WINDOW_MS: number = 24 * 60 * 60 * 1000;

  public static resolve(item: DDLItem, nowMs: number): DeadlineSemanticStatus {
    if (item.state === TaskState.ABANDONED || item.state === TaskState.ABANDONED_ARCHIVED) {
      return DeadlineSemanticStatus.ABANDONED;
    }
    if (item.state === TaskState.COMPLETED || item.state === TaskState.ARCHIVED) {
      return DeadlineSemanticStatus.COMPLETED;
    }

    const dueMs: number = DeadlineStatusResolver.parseTime(item.endTime);
    if (dueMs < 0) {
      return DeadlineSemanticStatus.ACTIVE;
    }
    if (dueMs < nowMs) {
      return DeadlineSemanticStatus.OVERDUE;
    }
    if (dueMs - nowMs <= DeadlineStatusResolver.NEAR_DUE_WINDOW_MS) {
      return DeadlineSemanticStatus.NEAR_DUE;
    }
    return DeadlineSemanticStatus.ACTIVE;
  }

  public static resolveProgress(item: DDLItem, nowMs: number): number {
    const status: DeadlineSemanticStatus = DeadlineStatusResolver.resolve(item, nowMs);
    if (status === DeadlineSemanticStatus.COMPLETED) {
      return 1;
    }
    if (status === DeadlineSemanticStatus.ABANDONED) {
      return 0;
    }

    const startMs: number = DeadlineStatusResolver.parseTime(item.startTime);
    const dueMs: number = DeadlineStatusResolver.parseTime(item.endTime);
    if (startMs < 0 || dueMs < 0 || dueMs <= startMs) {
      return 0;
    }

    const progress: number = (nowMs - startMs) / (dueMs - startMs);
    return Math.max(0, Math.min(1, progress));
  }

  public static toDDLStatus(status: DeadlineSemanticStatus): DDLStatus {
    switch (status) {
      case DeadlineSemanticStatus.ABANDONED:
        return DDLStatus.ABANDONED;
      case DeadlineSemanticStatus.COMPLETED:
        return DDLStatus.COMPLETED;
      case DeadlineSemanticStatus.OVERDUE:
        return DDLStatus.PASSED;
      case DeadlineSemanticStatus.NEAR_DUE:
        return DDLStatus.NEAR;
      case DeadlineSemanticStatus.ACTIVE:
      default:
        return DDLStatus.UNDERGO;
    }
  }

  private static parseTime(value: string): number {
    const parsed: number = new Date(value).getTime();
    return isNaN(parsed) ? -1 : parsed;
  }
}
