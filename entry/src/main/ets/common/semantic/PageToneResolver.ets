import { DDLItem } from '../../model/DDLModels';
import { DeadlineStatusResolver } from './DeadlineStatusResolver';
import {
  DeadlineSemanticStatus,
  HabitSemanticInput,
  SemanticPageKind,
  SemanticSnapshot,
  SemanticTone
} from './SemanticContract';

export class PageToneResolver {
  public static resolveTasks(items: DDLItem[], nowMs: number): SemanticSnapshot {
    const statusById: Map<number, DeadlineSemanticStatus> = new Map<number, DeadlineSemanticStatus>();
    let overdueCount: number = 0;
    let nearDueCount: number = 0;
    let openTaskCount: number = 0;
    let completedTaskCount: number = 0;
    let abandonedTaskCount: number = 0;

    for (let index: number = 0; index < items.length; index++) {
      const item: DDLItem = items[index];
      const status: DeadlineSemanticStatus = DeadlineStatusResolver.resolve(item, nowMs);
      statusById.set(item.id, status);

      if (status === DeadlineSemanticStatus.OVERDUE) {
        overdueCount++;
        openTaskCount++;
      } else if (status === DeadlineSemanticStatus.NEAR_DUE) {
        nearDueCount++;
        openTaskCount++;
      } else if (status === DeadlineSemanticStatus.ACTIVE) {
        openTaskCount++;
      } else if (status === DeadlineSemanticStatus.COMPLETED) {
        completedTaskCount++;
      } else if (status === DeadlineSemanticStatus.ABANDONED) {
        abandonedTaskCount++;
      }
    }

    let tone: SemanticTone = SemanticTone.SUCCESS;
    if (overdueCount > 0) {
      tone = SemanticTone.DANGER;
    } else if (nearDueCount > 0) {
      tone = SemanticTone.WARNING;
    } else if (openTaskCount > 0) {
      tone = SemanticTone.ACCENT;
    }

    return new SemanticSnapshot(
      SemanticPageKind.TASKS,
      tone,
      statusById,
      overdueCount,
      nearDueCount,
      openTaskCount,
      completedTaskCount,
      abandonedTaskCount,
      items.length,
      0,
      0
    );
  }

  public static resolveHabits(items: HabitSemanticInput[]): SemanticSnapshot {
    let completedHabitCount: number = 0;
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].isCompleted) {
        completedHabitCount++;
      }
    }

    const tone: SemanticTone = items.length > 0 && completedHabitCount === items.length
      ? SemanticTone.SUCCESS
      : SemanticTone.ACCENT;

    return new SemanticSnapshot(
      SemanticPageKind.HABITS,
      tone,
      new Map<number, DeadlineSemanticStatus>(),
      0,
      0,
      0,
      0,
      0,
      0,
      completedHabitCount,
      items.length
    );
  }
}
