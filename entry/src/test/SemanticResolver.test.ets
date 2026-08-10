import { describe, expect, it } from '@ohos/hypium';
import { DDLItem, DeadlineType } from '../main/ets/model/DDLModels';
import { TaskState } from '../main/ets/model/TaskStateMachine';
import { DeadlineStatusResolver } from '../main/ets/common/semantic/DeadlineStatusResolver';
import { PageToneResolver } from '../main/ets/common/semantic/PageToneResolver';
import {
  DeadlineSemanticStatus,
  HabitSemanticInput,
  SemanticTone
} from '../main/ets/common/semantic/SemanticContract';

function makeTask(id: number, state: TaskState, endTime: string): DDLItem {
  return {
    id: id,
    name: 'task',
    startTime: '2026-08-08T10:00:00.000Z',
    endTime: endTime,
    state: state,
    isCompleted: state === TaskState.COMPLETED || state === TaskState.ARCHIVED,
    completeTime: '',
    note: '',
    isArchived: state === TaskState.ARCHIVED || state === TaskState.ABANDONED_ARCHIVED,
    isStared: false,
    type: DeadlineType.TASK,
    habitCount: 0,
    habitTotalCount: 0,
    calendarEventId: null,
    categoryUid: null,
    timeStamp: '',
    uid: 'test-' + id.toString(),
    deleted: false,
    verTs: '',
    verCtr: 0,
    verDev: 'test'
  };
}

export default function semanticResolverTests() {
  const nowMs: number = new Date('2026-08-09T10:00:00.000Z').getTime();

  describe('SemanticResolver', () => {
    it('keeps abandoned and completed ahead of time risk', 0, () => {
      const expiredAt: string = '2026-08-08T09:00:00.000Z';
      expect(DeadlineStatusResolver.resolve(makeTask(1, TaskState.ABANDONED, expiredAt), nowMs))
        .assertEqual(DeadlineSemanticStatus.ABANDONED);
      expect(DeadlineStatusResolver.resolve(makeTask(2, TaskState.ABANDONED_ARCHIVED, expiredAt), nowMs))
        .assertEqual(DeadlineSemanticStatus.ABANDONED);
      expect(DeadlineStatusResolver.resolve(makeTask(3, TaskState.COMPLETED, expiredAt), nowMs))
        .assertEqual(DeadlineSemanticStatus.COMPLETED);
      expect(DeadlineStatusResolver.resolve(makeTask(4, TaskState.ARCHIVED, expiredAt), nowMs))
        .assertEqual(DeadlineSemanticStatus.COMPLETED);
    });

    it('uses an inclusive 24 hour near-due boundary', 0, () => {
      expect(DeadlineStatusResolver.resolve(makeTask(1, TaskState.ACTIVE, '2026-08-10T10:00:00.000Z'), nowMs))
        .assertEqual(DeadlineSemanticStatus.NEAR_DUE);
      expect(DeadlineStatusResolver.resolve(makeTask(2, TaskState.ACTIVE, '2026-08-10T10:00:00.001Z'), nowMs))
        .assertEqual(DeadlineSemanticStatus.ACTIVE);
      expect(DeadlineStatusResolver.resolve(makeTask(3, TaskState.ACTIVE, '2026-08-09T09:59:59.999Z'), nowMs))
        .assertEqual(DeadlineSemanticStatus.OVERDUE);
    });

    it('treats an invalid due time as active', 0, () => {
      expect(DeadlineStatusResolver.resolve(makeTask(1, TaskState.ACTIVE, 'not-a-date'), nowMs))
        .assertEqual(DeadlineSemanticStatus.ACTIVE);
    });

    it('aggregates only the supplied visible tasks by highest risk', 0, () => {
      const visible: DDLItem[] = [
        makeTask(1, TaskState.ACTIVE, '2026-08-09T09:00:00.000Z'),
        makeTask(2, TaskState.ACTIVE, '2026-08-10T09:00:00.000Z'),
        makeTask(3, TaskState.COMPLETED, '2026-08-08T09:00:00.000Z')
      ];
      const snapshot = PageToneResolver.resolveTasks(visible, nowMs);
      expect(snapshot.tone).assertEqual(SemanticTone.DANGER);
      expect(snapshot.overdueCount).assertEqual(1);
      expect(snapshot.nearDueCount).assertEqual(1);
      expect(snapshot.openTaskCount).assertEqual(2);
      expect(snapshot.completedTaskCount).assertEqual(1);
    });

    it('returns success for an empty task scope', 0, () => {
      expect(PageToneResolver.resolveTasks([], nowMs).tone).assertEqual(SemanticTone.SUCCESS);
    });

    it('returns habit success only when a non-empty visible scope is complete', 0, () => {
      const completed: HabitSemanticInput[] = [
        new HabitSemanticInput(1, true),
        new HabitSemanticInput(2, true)
      ];
      const pending: HabitSemanticInput[] = [
        new HabitSemanticInput(1, true),
        new HabitSemanticInput(2, false)
      ];
      expect(PageToneResolver.resolveHabits(completed).tone).assertEqual(SemanticTone.SUCCESS);
      expect(PageToneResolver.resolveHabits(pending).tone).assertEqual(SemanticTone.ACCENT);
      expect(PageToneResolver.resolveHabits([]).tone).assertEqual(SemanticTone.ACCENT);
    });
  });
}
